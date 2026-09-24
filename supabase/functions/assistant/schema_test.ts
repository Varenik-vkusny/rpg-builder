// Схема плана держит сервер: Gemini не гарантирует её, как `strict` у Claude.
import assert from "node:assert/strict";
import { test } from "node:test";

import { floodPlan, mines, scripted, toolUse } from "./fixtures_test_data.ts";
import { handle } from "./handler.ts";
import { TOOLS } from "./plan.ts";
import { checkSchema } from "./schema_check.ts";

const PLAN = TOOLS.find((t) => t.name === "propose_plan")!.input_schema;
const ask = {
  project_id: "w1",
  scope: { type: "location", slug: "shtolnya_3" },
  request: "затопи её",
  attempt: 0,
  previous_plan: null,
  problems: [],
};
const clone = <T>(v: T): T => JSON.parse(JSON.stringify(v));

test("схема: образец плана проходит без ошибок и не меняется", () => {
  const r = checkSchema(floodPlan, PLAN);
  assert.deepEqual(r.errors, []);
  assert.deepEqual(r.value, floodPlan);
});

test("схема: пропущенные null-поля дополняются null", () => {
  const p = clone(floodPlan) as unknown as { ops: Record<string, unknown>[] };
  delete p.ops[0].character;
  delete (p.ops[0].fields as Record<string, unknown>).hp;
  const r = checkSchema(p, PLAN);
  assert.deepEqual(r.errors, []);
  assert.deepEqual(r.value, floodPlan);
});

test("схема: чужой вид, дробный уровень, строка вместо числа, лишнее поле — ошибки с путём", () => {
  const p = clone(floodPlan) as unknown as { ops: Record<string, Record<string, unknown>>[] } & Record<string, unknown>;
  p.ops[0].fields.kind = "sword";
  p.ops[0].fields.level = 2.5;
  p.ops[0].fields.attack = "8";
  p.extra = 1;
  const { errors } = checkSchema(p, PLAN);
  assert.equal(errors.length, 4, errors.join("\n"));
  for (const k of ["ops[0].fields.kind", "ops[0].fields.level", "ops[0].fields.attack", "extra"]) {
    assert.ok(errors.some((e) => e.startsWith(k)), k);
  }
});

test("схема: без summary и без ops — ошибка", () => {
  assert.equal(checkSchema({}, PLAN).errors.length, 2);
  assert.equal(checkSchema({ summary: "x", ops: "нет" }, PLAN).errors.length, 1);
});

test("схема: план не по схеме не уходит на телефон — модель получает ошибку и исправляет", async () => {
  const bad = clone(floodPlan) as unknown as { ops: Record<string, Record<string, unknown>>[] };
  bad.ops[0].fields.role = "boss";
  const { deps, calls } = scripted(mines, [
    toolUse("t1", "propose_plan", bad),
    toolUse("t2", "propose_plan", floodPlan),
  ]);
  const r = await handle(ask, deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.plan, floodPlan);
  const reply = (calls[1].messages[2].content as { is_error: boolean; content: string }[])[0];
  assert.equal(reply.is_error, true);
  assert.match(reply.content, /не по схеме[\s\S]*ops\[0\]\.fields\.role/);
});

test("схема: модель так и не прислала план по схеме — 502, кривой план не отдан", async () => {
  const bad = { summary: "x", ops: [{ action: "explode" }] };
  const { deps } = scripted(mines, Array.from({ length: 8 }, (_, i) => toolUse(`t${i}`, "propose_plan", bad)));
  const r = await handle(ask, deps);
  assert.equal(r.status, 502);
  assert.equal(r.body.plan, undefined);
});
