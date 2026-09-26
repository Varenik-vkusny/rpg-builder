// Схему плана держит сервер: бесплатные модели её не гарантируют, как `strict` у Claude.
// Модель пишет короткий формат (у каждого вида — свои поля), телефон получает прежний (ops.ts).
import assert from "node:assert/strict";
import { test } from "node:test";

import { floodPlan, mines, planUse, scripted, toolUse } from "./fixtures_test_data.ts";
import { handle, MAX_TURNS } from "./handler.ts";
import { OP_TYPES, PLAN_INPUT_SCHEMA, toPlan, toShort } from "./ops.ts";
import { TOOLS } from "./plan.ts";

const ask = {
  project_id: "w1",
  scope: { type: "location", slug: "shtolnya_3" },
  request: "затопи её",
  attempt: 0,
  previous_plan: null,
  problems: [],
};
const clone = <T>(v: T): T => JSON.parse(JSON.stringify(v));
type Short = { summary: string; ops: Record<string, unknown>[] } & Record<string, unknown>;
const short = () => clone(toShort(floodPlan)) as Short;

test("короткая схема: модель видит у каждого вида только его поля", () => {
  assert.equal(TOOLS.find((t) => t.name === "propose_plan")!.input_schema, PLAN_INPUT_SCHEMA);
  const kinds = PLAN_INPUT_SCHEMA.properties.ops.items.anyOf;
  assert.deepEqual(kinds.map((k) => k.properties.type.enum[0]), OP_TYPES);
  const props = (t: string) => Object.keys(kinds.find((k) => k.properties.type.enum[0] === t)!.properties);
  assert.deepEqual(props("loot"), ["action", "type", "character", "item", "chance"]);
  assert.deepEqual(props("quest_reward"), ["action", "type", "quest", "item"]);
  assert.ok(!props("location").includes("attack"));
  // Самый длинный вид — не больше 10 полей (было ~25 у каждой операции).
  assert.ok(Math.max(...kinds.map((k) => Object.keys(k.properties).length)) <= 10);
});

test("короткая схема: образец в коротком формате без пустых полей и переводится обратно без потерь", () => {
  const s = short();
  assert.deepEqual(s.ops[2], { action: "delete", type: "loot", character: "slizen", item: "klyuch" });
  assert.ok(!JSON.stringify(s).includes("null"));
  const r = toPlan(s);
  assert.deepEqual(r.errors, []);
  assert.deepEqual(r.plan, floodPlan);
});

test("короткая схема: поле чужого вида, дробный уровень, строка вместо числа, лишнее поле — ошибки с путём", () => {
  const s = short();
  s.ops[0].attack = 3; // у локации атаки нет
  s.ops[1].level = 2.5;
  s.ops[1].hp = "8";
  s.extra = 1;
  const { plan, errors } = toPlan(s);
  assert.equal(plan, null);
  assert.equal(errors.length, 4, errors.join("; "));
  for (const k of ["extra", "ops[0].attack", "ops[1].level", "ops[1].hp"]) {
    assert.ok(errors.some((e) => e.startsWith(k)), k);
  }
});

test("короткая схема: чужой вид операции, без summary и без ops — ошибка", () => {
  assert.match(toPlan({ summary: "x", ops: [{ action: "create", type: "dragon" }] }).errors[0], /ops\[0\]\.type: "dragon" не из location\|/);
  assert.equal(toPlan({}).errors.length, 2);
  assert.equal(toPlan({ summary: "x", ops: "нет" }).errors.length, 1);
});

test("схема: план не по схеме не уходит на телефон — модель получает ошибку и исправляет", async () => {
  const bad = short();
  bad.ops[1].role = "boss";
  const { deps, calls } = scripted(mines, [
    toolUse("t1", "propose_plan", bad),
    planUse("t2", floodPlan),
  ]);
  const r = await handle(ask, deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.plan, floodPlan);
  const reply = (calls[1].messages[2].content as { is_error: boolean; content: string }[])[0];
  assert.equal(reply.is_error, true);
  assert.match(reply.content, /не по схеме[\s\S]*ops\[1\]\.role/);
});

test("схема: модель так и не прислала план по схеме — 502, кривой план не отдан", async () => {
  const bad = { summary: "x", ops: [{ action: "explode", type: "location", slug: "shtolnya_3" }] };
  const { deps } = scripted(mines, Array.from({ length: MAX_TURNS }, (_, i) => toolUse(`t${i}`, "propose_plan", bad)));
  const r = await handle(ask, deps);
  assert.equal(r.status, 502);
  assert.equal(r.body.plan, undefined);
  // Что делала модель — в ответе: так видно, почему плана нет.
  assert.match(String(r.body.error), /4 ходов: план не по схеме \(ops\[0\]\.action/);
  assert.equal((r.body.trace as string[]).length, MAX_TURNS);
});
