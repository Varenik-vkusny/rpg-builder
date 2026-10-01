// Вложенность мест в области ассистента (5а.6): место тянет вложенные на 1 уровень
// и их жителей; модель видит родителя и может положить место внутрь другого.
import assert from "node:assert/strict";
import { test } from "node:test";

import { mines, op } from "./fixtures_test_data.ts";
import type { Plan } from "./plan.ts";
import { outOfScope } from "./plan.ts";
import { toPlan } from "./ops.ts";
import { systemPrompt } from "./prompt.ts";
import type { World } from "./world.ts";
import { scopeOf } from "./world.ts";

/// Копи › Штольня №3 › Забой; в забое — забойщик.
const nested: World = {
  ...mines,
  locations: [
    { slug: "kopi", title: "Копи", description: "", level_min: 1, level_max: 6, parent: null },
    ...mines.locations.map((l) => (l.slug === "shtolnya_3" ? { ...l, parent: "kopi" } : l)),
    { slug: "zaboy", title: "Забой", description: "", level_min: 3, level_max: 4, parent: "shtolnya_3" },
  ],
  characters: [
    ...mines.characters,
    { slug: "zaboyshchik", title: "Забойщик", description: "", role: "npc", level: 3, hp: 10, attack: 0, location: "zaboy", loot: [] },
  ],
};

const kopiScope = () => scopeOf(nested, "location", "kopi");
const plan = (...ops: Plan["ops"]): Plan => ({ summary: "", ops });

test("вложенность: область Копей — штольня внутри и её жители", () => {
  const s = kopiScope();
  assert.ok(s.has("location:shtolnya_3"), [...s].join(" "));
  assert.ok(s.has("character:slizen"), "житель штольни");
  // Только 1 уровень вниз: забой и его житель — нет.
  assert.ok(!s.has("location:zaboy"));
  assert.ok(!s.has("character:zaboyshchik"));
});

test("вложенность: «затопи копи» может менять штольни внутри", () => {
  const flood = plan(
    op({ type: "location", slug: "kopi", fields: { description: "затоплены" } }),
    op({ type: "location", slug: "shtolnya_3", fields: { description: "затоплена по пояс" } }),
    op({ action: "delete", type: "loot", character: "slizen", item: "klyuch" }),
  );
  assert.deepEqual(outOfScope(flood, kopiScope()), []);
});

test("вложенность: область штольни не тянет родителя вверх", () => {
  const s = scopeOf(nested, "location", "shtolnya_3");
  assert.ok(!s.has("location:kopi"));
  assert.ok(s.has("location:zaboy"));
});

test("вложенность: модель кладёт место внутрь — parent доходит до плана", () => {
  const r = toPlan({
    summary: "колодец",
    ops: [{ action: "create", type: "location", slug: "kolodec", title: "Колодец", level_min: 2, level_max: 3, parent: "shtolnya_3" }],
  });
  assert.deepEqual(r.errors, []);
  assert.equal(r.plan!.ops[0].fields.parent, "shtolnya_3");
});

test("вложенность: родитель вне области — отклоняется", () => {
  const p = plan(op({ type: "location", slug: "shtolnya_3", fields: { parent: "rynok" } }));
  const bad = outOfScope(p, scopeOf(nested, "location", "shtolnya_3"));
  assert.equal(bad.length, 1, bad.join("; "));
  assert.match(bad[0], /location:rynok/);
});

test("вложенность: модель видит родителя мест и правило трёх уровней", () => {
  const text = systemPrompt(nested, kopiScope());
  assert.match(text, /"parent":"kopi"/);
  assert.match(text, /не глубже 3 уровней/);
});
