// Сервер чинит план до проверки на копии: опечатку в slug (только однозначную) и порядок операций.
import assert from "node:assert/strict";
import { test } from "node:test";

import { floodPlan, mines, op, planUse, scripted } from "./fixtures_test_data.ts";
import { handle } from "./handler.ts";
import type { Plan } from "./plan.ts";
import { outOfScope } from "./plan.ts";
import { isTypo, repairPlan } from "./repair.ts";
import { objectsByKey, scopeOf } from "./world.ts";

const scope = scopeOf(mines, "location", "shtolnya_3");
const world = new Set(objectsByKey(mines).keys());
const plan = (...ops: Plan["ops"]): Plan => ({ summary: "x", ops });
const ask = {
  project_id: "w1",
  scope: { type: "location", slug: "shtolnya_3" },
  request: "затопи её",
  attempt: 0,
  previous_plan: null,
  problems: [],
  answers: [{ question: "q", answer: "a" }, { question: "q", answer: "a" }],
};

test("починка: опечатка с одним близким slug в области чинится и помечена", () => {
  const p = repairPlan(plan(op({ type: "character", slug: "slizn", fields: { attack: 4 } })), scope, world);
  assert.equal(p.ops[0].slug, "slizen");
  assert.deepEqual(p.ops[0].repairs, ["опечатка в slug: slizn → slizen"]);
  assert.deepEqual(outOfScope(p, scope, world), []);
});

test("починка: опечатка в ссылке на созданный планом объект чинится", () => {
  const p = repairPlan(plan(
    op({ action: "create", type: "character", slug: "utoplennik", fields: { role: "enemy" } }),
    op({ action: "create", type: "loot", character: "utoplenik", item: "klyuch", fields: { chance: 35 } }),
  ), scope, world);
  assert.equal(p.ops[1].character, "utoplennik");
});

test("починка: опечатка с двумя близкими совпадениями не чинится", () => {
  // slizenn близко и к slizen (в области), и к slizen_2 (создаёт план) — какой имелся в виду, не угадать.
  const p = repairPlan(plan(
    op({ action: "create", type: "character", slug: "slizen_2", fields: { role: "enemy" } }),
    op({ type: "character", slug: "slizenn", fields: { attack: 4 } }),
  ), scope, world);
  assert.equal(p.ops[1].slug, "slizenn");
  assert.equal(p.ops[1].repairs, undefined);
  assert.match(outOfScope(p, scope, world)[0], /character:slizenn нет в мире/);
});

test("починка: опечатка вне области не чинится", () => {
  // torgovkaa — опечатка в торговке, а она вне области штольни. Похожий torgovka_2 план создаёт,
  // но подставить его — значит молча поменять смысл: остаётся ошибкой модели.
  const p = repairPlan(plan(
    op({ action: "create", type: "character", slug: "torgovka_2", fields: { role: "merchant" } }),
    op({ type: "character", slug: "torgovkaa", fields: { attack: 1 } }),
  ), scope, world);
  assert.equal(p.ops[1].slug, "torgovkaa");
  assert.equal(p.ops[1].repairs, undefined);
});

test("починка: объект вне области без опечатки не трогается", () => {
  const p = repairPlan(plan(op({ type: "location", slug: "rynok", fields: { description: "x" } })), scope, world);
  assert.equal(p.ops[0].slug, "rynok");
  assert.equal(p.ops[0].repairs, undefined);
});

test("починка: порядок чинится — создать, потом ссылки, потом удалить", () => {
  const p = repairPlan(plan(
    op({ action: "delete", type: "character", slug: "slizen" }),
    op({ type: "quest_step", quest: "obval", position: 2, fields: { step_kind: "kill", target: "utoplennik", amount: 3 } }),
    op({ action: "create", type: "character", slug: "utoplennik", fields: { role: "enemy", location: "shtolnya_3" } }),
    op({ action: "delete", type: "loot", character: "slizen", item: "klyuch" }),
  ), scope, world);
  assert.deepEqual(p.ops.map((o) => `${o.action} ${o.type}`), [
    "create character", "update quest_step", "delete loot", "delete character",
  ]);
  assert.deepEqual(p.ops[0].repairs, ["порядок: была операция 3, стала 1"]);
  assert.deepEqual(p.ops[3].repairs, ["порядок: была операция 1, стала 4"]);
  assert.equal(p.ops[1].repairs, undefined);
});

test("починка: порядок — удаление врага после шага квеста, который с него переписан (живой прогон)", () => {
  // Шаг переписан на утопленника: слизня в операции шага нет, но удалять его раньше — ошибка копии.
  const p = repairPlan(plan(
    op({ action: "create", type: "character", slug: "utoplennik", fields: { role: "enemy" } }),
    op({ action: "delete", type: "character", slug: "slizen" }),
    op({ type: "quest_step", quest: "obval", position: 2, fields: { step_kind: "kill", target: "utoplennik", amount: 3 } }),
  ), scope, world);
  assert.deepEqual(p.ops.map((o) => `${o.action} ${o.type}`), ["create character", "update quest_step", "delete character"]);
  assert.deepEqual(p.ops[2].repairs, ["порядок: была операция 2, стала 3"]);
});

test("починка: правильный план не меняется и без пометок", () => {
  assert.deepEqual(repairPlan(floodPlan, scope, world), floodPlan);
});

test("починка: пометки доходят до телефона вместе с планом", async () => {
  const bad = plan(op({ type: "character", slug: "slizn", fields: { attack: 4 } }));
  const { deps } = scripted(mines, [planUse("p", bad)]);
  const r = await handle(ask, deps);
  assert.equal(r.status, 200);
  const ops = (r.body.plan as Plan).ops;
  assert.equal(ops[0].slug, "slizen");
  assert.deepEqual(ops[0].repairs, ["опечатка в slug: slizn → slizen"]);
});

test("починка: близость — 1 правка у коротких slug, 2 до 10 букв", () => {
  assert.ok(isTypo("klyuc", "klyuch"));
  assert.ok(!isTypo("rynok", "kirka"));
  assert.ok(isTypo("utoplenik_3", "utoplennik"));
});
