// Операции с событиями (5б, Ступень 2): event / event_enemy / event_item — схема, область, починка, порядок.
import assert from "node:assert/strict";
import { test } from "node:test";

import { mines, op, planUse, scripted } from "./fixtures_test_data.ts";
import { handle } from "./handler.ts";
import { toPlan, toShort } from "./ops.ts";
import type { Plan } from "./plan.ts";
import { outOfScope } from "./plan.ts";
import { systemPrompt } from "./prompt.ts";
import { repairPlan } from "./repair.ts";
import type { World, WorldEvent } from "./world.ts";
import { eventKeysInScope, scopeOf, worldKeys } from "./world.ts";

const ev = (slug: string, o: Partial<WorldEvent> = {}): WorldEvent => ({
  slug, title: slug, description: "", location: "shtolnya_3",
  enemies: [{ enemy: "slizen", amount: 3 }], items: ["klyuch"], ...o,
});
/// Событие у слизня в штольне (касается области) и тихое на рынке (не касается).
const inside = ev("zasada");
const quiet = ev("rynok_draka", { location: "rynok", enemies: [], items: [] });
const world: World = { ...mines, events: [inside, quiet] };
const scope = scopeOf(world, "location", "shtolnya_3");
const allowed = new Set([...scope, ...eventKeysInScope(world, scope)]);
const wk = worldKeys(world);
const plan = (...ops: Plan["ops"]): Plan => ({ summary: "x", ops });

test("событие-оп: короткая схема принимает все три вида и переводит в формат приложения", () => {
  const { plan: p, errors } = toPlan({
    summary: "s",
    ops: [
      { action: "create", type: "event", slug: "zasada", title: "Засада", description: "у лебёдки", location: "shtolnya_3" },
      { action: "create", type: "event_enemy", event: "zasada", character: "slizen", amount: 2 },
      { action: "create", type: "event_item", event: "zasada", item: "klyuch" },
    ],
  });
  assert.deepEqual(errors, []);
  assert.deepEqual(p!.ops.map((o) => [o.type, o.slug, o.event, o.character, o.item]), [
    ["event", "zasada", null, null, null],
    ["event_enemy", null, "zasada", "slizen", null],
    ["event_item", null, "zasada", null, "klyuch"],
  ]);
  assert.equal(p!.ops[0].fields.location, "shtolnya_3");
  assert.equal(p!.ops[0].fields.title, "Засада");
  assert.equal(p!.ops[1].fields.amount, 2);
});

test("событие-оп: схема отклоняет лишние поля и пропущенные id", () => {
  const bad = (o: unknown) => toPlan({ summary: "s", ops: [o] });
  // у event_item нет amount, у event_enemy нет chance, у event нет amount
  assert.notEqual(bad({ action: "create", type: "event_item", event: "z", item: "k", amount: 1 }).errors.length, 0);
  assert.notEqual(bad({ action: "create", type: "event_enemy", event: "z", character: "s", chance: 5 }).errors.length, 0);
  assert.notEqual(bad({ action: "create", type: "event", slug: "z", amount: 1 }).errors.length, 0);
  // нет character / нет event / нет slug
  assert.match(bad({ action: "create", type: "event_enemy", event: "z", amount: 1 }).errors.join(), /character/);
  assert.match(bad({ action: "delete", type: "event_item", item: "k" }).errors.join(), /event/);
  assert.match(bad({ action: "delete", type: "event" }).errors.join(), /slug/);
  // amount — целое
  assert.notEqual(bad({ action: "update", type: "event_enemy", event: "z", character: "s", amount: 1.5 }).errors.length, 0);
});

test("событие-оп: toShort возвращает то, что прислала модель", () => {
  const short = {
    summary: "s",
    ops: [
      { action: "update", type: "event", slug: "zasada", title: "Новое", location: "shtolnya_3" },
      { action: "update", type: "event_enemy", event: "zasada", character: "slizen", amount: 5 },
      { action: "delete", type: "event_item", event: "zasada", item: "klyuch" },
    ],
  };
  assert.deepEqual(toShort(toPlan(short).plan!), short);
});

test("событие-оп: область допуска — место, враг, предмет события или шаг квеста области", () => {
  assert.deepEqual([...eventKeysInScope(world, scope)], ["event:zasada"]);
  const onlyEnemy: World = { ...world, events: [ev("e1", { location: "rynok", items: [] })] };
  assert.deepEqual([...eventKeysInScope(onlyEnemy, scope)], ["event:e1"]);
  const onlyItem: World = { ...world, events: [ev("e2", { location: "rynok", enemies: [] })] };
  assert.deepEqual([...eventKeysInScope(onlyItem, scope)], ["event:e2"]);
  const viaStep: World = {
    ...world,
    events: [quiet],
    quests: [{ ...mines.quests[0], steps: [{ kind: "event", target: "rynok_draka", amount: null }] }],
  };
  assert.deepEqual([...eventKeysInScope(viaStep, scope)], ["event:rynok_draka"]);
  assert.deepEqual([...worldKeys(world)].filter((k) => k.startsWith("event:")).sort(), ["event:rynok_draka", "event:zasada"]);
});

test("событие-оп: создать событие в месте области вместе с врагом и предметом — можно", () => {
  const p = plan(
    op({ action: "create", type: "event", slug: "novoe", fields: { title: "Новое", location: "shtolnya_3" } }),
    op({ action: "create", type: "event_enemy", event: "novoe", character: "slizen", fields: { amount: 2 } }),
    op({ action: "create", type: "event_item", event: "novoe", item: "klyuch" }),
  );
  assert.deepEqual(outOfScope(p, allowed, wk), []);
});

test("событие-оп: событие в месте вне области — отклоняется", () => {
  const p = plan(op({ action: "create", type: "event", slug: "novoe", fields: { title: "Новое", location: "rynok" } }));
  assert.match(outOfScope(p, allowed, wk).join("\n"), /location:rynok вне области/);
});

test("событие-оп: изменить и удалить событие, которого касается область, — можно", () => {
  const p = plan(
    op({ type: "event", slug: "zasada", fields: { title: "Иное" } }),
    op({ type: "event_enemy", event: "zasada", character: "slizen", fields: { amount: 1 } }),
    op({ action: "delete", type: "event_item", event: "zasada", item: "klyuch" }),
    op({ action: "delete", type: "event", slug: "zasada" }),
  );
  assert.deepEqual(outOfScope(p, allowed, wk), []);
});

test("событие-оп: изменить, удалить и дополнить событие вне области — отклоняется", () => {
  for (const o of [
    op({ type: "event", slug: "rynok_draka", fields: { title: "Иное" } }),
    op({ action: "delete", type: "event", slug: "rynok_draka" }),
    op({ action: "create", type: "event_enemy", event: "rynok_draka", character: "slizen", fields: { amount: 1 } }),
    op({ action: "create", type: "event_item", event: "rynok_draka", item: "klyuch" }),
  ]) {
    assert.match(outOfScope(plan(o), allowed, wk).join("\n"), /event:rynok_draka вне области/);
  }
});

test("событие-оп: опечатка в slug события чинится, если кандидат один", () => {
  const p = repairPlan(plan(op({ type: "event", slug: "zasda", fields: { title: "Иное" } })), allowed, wk);
  assert.equal(p.ops[0].slug, "zasada");
  assert.deepEqual(p.ops[0].repairs, ["опечатка в slug: zasda → zasada"]);
  assert.deepEqual(outOfScope(p, allowed, wk), []);
});

test("событие-оп: опечатка в event у врага события чинится", () => {
  const p = repairPlan(plan(
    op({ type: "event_enemy", event: "zasad", character: "slizen", fields: { amount: 1 } }),
  ), allowed, wk);
  assert.equal(p.ops[0].event, "zasada");
  assert.deepEqual(p.ops[0].repairs, ["опечатка в slug: zasad → zasada"]);
});

test("событие-оп: опечатка с двумя близкими событиями не чинится", () => {
  const two: World = { ...mines, events: [ev("zasada_a"), ev("zasada_b")] };
  const sc = scopeOf(two, "location", "shtolnya_3");
  const al = new Set([...sc, ...eventKeysInScope(two, sc)]);
  const p = repairPlan(plan(op({ type: "event", slug: "zasada_c", fields: { title: "Иное" } })), al, worldKeys(two));
  assert.equal(p.ops[0].slug, "zasada_c");
  assert.equal(p.ops[0].repairs, undefined);
});

test("событие-оп: создание события встаёт раньше создания его врага и предмета", () => {
  const p = repairPlan(plan(
    op({ action: "create", type: "event_enemy", event: "novoe", character: "slizen", fields: { amount: 2 } }),
    op({ action: "create", type: "event_item", event: "novoe", item: "klyuch" }),
    op({ action: "create", type: "event", slug: "novoe", fields: { title: "Новое", location: "shtolnya_3" } }),
  ), allowed, wk);
  assert.deepEqual(p.ops.map((o) => o.type), ["event", "event_enemy", "event_item"]);
  assert.match(p.ops[0].repairs![0], /порядок: была операция 3, стала 1/);
});

test("событие-оп: место создано раньше всех, но событие в нём перенесено вперёд — место тянется за ним", () => {
  const p = repairPlan(plan(
    op({ action: "create", type: "location", slug: "podval", fields: { title: "Подвал" } }),
    op({ action: "create", type: "event_item", event: "novoe", item: "klyuch" }),
    op({ action: "create", type: "event", slug: "novoe", fields: { title: "Новое", location: "podval" } }),
  ), allowed, wk);
  assert.deepEqual(p.ops.map((o) => o.type), ["location", "event", "event_item"]);
});

test("событие-оп: новый враг создаётся раньше, чем его ставят в событие", () => {
  const p = repairPlan(plan(
    op({ action: "create", type: "event_enemy", event: "zasada", character: "utoplennik", fields: { amount: 2 } }),
    op({ action: "create", type: "character", slug: "utoplennik", fields: { title: "Утопленник", role: "enemy", location: "shtolnya_3" } }),
  ), allowed, wk);
  assert.deepEqual(p.ops.map((o) => o.type), ["character", "event_enemy"]);
});

test("событие-оп: новое место создаётся раньше события, которое в нём происходит", () => {
  const p = repairPlan(plan(
    op({ action: "create", type: "event_item", event: "novoe", item: "klyuch" }),
    op({ action: "create", type: "event", slug: "novoe", fields: { title: "Новое", location: "podval" } }),
    op({ action: "create", type: "location", slug: "podval", fields: { title: "Подвал" } }),
  ), allowed, wk);
  assert.deepEqual(p.ops.map((o) => o.type), ["location", "event", "event_item"]);
});

test("событие-оп: удаление события и его врага — раньше удаления самого врага", () => {
  const p = repairPlan(plan(
    op({ action: "delete", type: "character", slug: "slizen" }),
    op({ action: "delete", type: "event", slug: "zasada" }),
    op({ action: "delete", type: "event_enemy", event: "zasada", character: "slizen" }),
  ), allowed, wk);
  assert.deepEqual(p.ops.map((o) => o.type), ["event_enemy", "event", "character"]);
});

test("событие-оп: удаление события, стоящее после удаления места и врага, встаёт раньше них", () => {
  const p = repairPlan(plan(
    op({ action: "delete", type: "character", slug: "slizen" }),
    op({ action: "delete", type: "event", slug: "zasada" }),
  ), allowed, wk);
  assert.deepEqual(p.ops.map((o) => o.type), ["event", "character"]);
  assert.match(p.ops[0].repairs![0], /порядок: была операция 2, стала 1/);
});

test("событие-оп: удаление предмета события, если оно последнее в плане, тоже встаёт раньше", () => {
  const p = repairPlan(plan(
    op({ action: "delete", type: "item", slug: "klyuch" }),
    op({ action: "delete", type: "event_item", event: "zasada", item: "klyuch" }),
  ), allowed, wk);
  assert.deepEqual(p.ops.map((o) => o.type), ["event_item", "item"]);
});

test("событие-оп: handle() — модель создаёт событие, ответ содержит три вида операций", async () => {
  const p = plan(
    op({ action: "create", type: "event", slug: "novoe", fields: { title: "Новое", description: "d", location: "shtolnya_3" } }),
    op({ action: "create", type: "event_enemy", event: "novoe", character: "slizen", fields: { amount: 2 } }),
    op({ action: "create", type: "event_item", event: "novoe", item: "klyuch" }),
  );
  const { deps } = scripted(mines, [planUse("t1", p)]);
  const r = await handle({
    project_id: "w1", scope: { type: "location", slug: "shtolnya_3" },
    request: "засада у штольни", attempt: 0, previous_plan: null, problems: [],
  }, deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.plan, p);
  assert.deepEqual((r.body.plan as Plan).ops.map((o) => o.type), ["event", "event_enemy", "event_item"]);
});

test("событие-оп: handle() — событие вне области: модель получает отказ с причиной", async () => {
  const bad = plan(op({ type: "event", slug: "rynok_draka", fields: { title: "Иное" } }));
  const good = plan(op({ type: "event", slug: "zasada", fields: { title: "Иное" } }));
  const { deps, calls } = scripted(world, [planUse("t1", bad), planUse("t2", good)]);
  const r = await handle({
    project_id: "w1", scope: { type: "location", slug: "shtolnya_3" },
    request: "переименуй", attempt: 0, previous_plan: null, problems: [],
  }, deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.plan, good);
  assert.match(JSON.stringify(calls[1].messages), /event:rynok_draka вне области/);
});

test("событие-оп: подсказка про операции событий есть, когда событие касается области", () => {
  const text = systemPrompt(world, scope);
  assert.match(text, /есть операции: event \(сцена[^)]*\), event_enemy[^)]*\), event_item/);
  assert.match(text, /удалять можно только после удаления события/);
  assert.doesNotMatch(text, /план их не меняет/);
});
