// События в подсказке ассистента (5б, Ступень 1): модель их видит и не ломает.
// Мир без событий — подсказка байт-в-байт прежняя (от неё зависит замер сцены «штольня»).
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";

import { floodPlan, mines, planUse, scripted } from "./fixtures_test_data.ts";
import { handle } from "./handler.ts";
import { loadWorld } from "./load_world.ts";
import { systemPrompt } from "./prompt.ts";
import type { World, WorldEvent } from "./world.ts";
import { objectsByKey, scopeOf, stepTargetType } from "./world.ts";

const SLUG = "zasada_u_lebedki";
const ambush = (o: Partial<WorldEvent> = {}): WorldEvent => ({
  slug: SLUG, title: "Засада у лебёдки", location: "shtolnya_3",
  enemies: [{ enemy: "slizen", amount: 3 }], items: ["klyuch"], ...o,
});
const withEvents = (...events: WorldEvent[]): World => ({ ...mines, events });
const prompt = (w: World) => systemPrompt(w, scopeOf(w, "location", "shtolnya_3"));

// Подсказка мира «копи» без событий, снятая до появления событий (08.10): длина в байтах и sha256.
const BASE_BYTES = 5845;
const BASE_SHA256 = "c124b22be7c5733703e83601d57391c155b6a5b18f25be6c76ab917af565fa2c";

test("событие: мир без событий — подсказка прежняя, слова «Событи» нет", () => {
  const text = prompt(mines);
  assert.doesNotMatch(text, /Событи/);
  assert.equal(Buffer.byteLength(text, "utf8"), BASE_BYTES);
  assert.equal(createHash("sha256").update(text).digest("hex"), BASE_SHA256);
});

test("событие: в месте области — строка с врагом × числом и предметом", () => {
  const text = prompt(withEvents(ambush()));
  assert.match(text, /События \(сцены в местах\) — план их не меняет:/);
  assert.match(
    text,
    /\n- «Засада у лебёдки» \(zasada_u_lebedki\) в location:shtolnya_3: враги character:slizen × 3; предметы item:klyuch\n/,
  );
  assert.match(text, /удалять нельзя/);
});

test("событие: место вне области, но враг из области — показано без места и без чужого", () => {
  const e = ambush({
    location: "rynok", enemies: [{ enemy: "torgovka", amount: 1 }, { enemy: "slizen", amount: 2 }], items: [],
  });
  const text = prompt(withEvents(e));
  assert.match(text, /\n- «Засада у лебёдки» \(zasada_u_lebedki\): враги character:slizen × 2\n/);
  assert.doesNotMatch(text, /rynok|torgovka/);
});

test("событие: не касается области — не показано", () => {
  const e = ambush({ location: "rynok", enemies: [{ enemy: "torgovka", amount: 1 }], items: [] });
  const text = prompt(withEvents(e));
  assert.doesNotMatch(text, /Событи|Засада/);
  assert.equal(Buffer.byteLength(text, "utf8"), BASE_BYTES);
});

/// Мир, где квест «Обвал» кончается шагом «пройти событие» (target — slug события).
const withEventStep = (e: WorldEvent): World => ({
  ...withEvents(e),
  quests: mines.quests.map((q) => ({ ...q, steps: [...q.steps, { kind: "event", target: SLUG, amount: null }] })),
});

test("событие: шаг квеста вида event — цель slug, область не падает и не тянет событие", () => {
  assert.equal(stepTargetType("event"), "event");
  const quiet = ambush({ location: "rynok", enemies: [{ enemy: "torgovka", amount: 1 }], items: [] });
  const w = withEventStep(quiet);
  const scope = scopeOf(w, "location", "shtolnya_3");
  assert.deepEqual([...scope].filter((k) => k.includes(SLUG) || k.startsWith("event:")), []);
  assert.deepEqual([...objectsByKey(w).keys()].filter((k) => k.startsWith("event:")), []);
  const text = systemPrompt(w, scope); // не падает на all.get(k)!
  assert.match(text, new RegExp(`"kind":"event","target":"${SLUG}"`));
  // Шаг из квеста области делает событие видимым, хотя ни место, ни враги в область не входят.
  assert.match(text, /\n- «Засада у лебёдки» \(zasada_u_lebedki\)\n/);
  // Состав области от событий не зависит.
  assert.deepEqual([...scope].sort(), [...scopeOf(mines, "location", "shtolnya_3")].sort());
  // Корень — сам квест с шагом event: событие рядом (1 связь), но ключа event:* нет.
  for (const [type, slug] of [["quest", "obval"], ["character", "brigadir"]] as const) {
    const s = scopeOf(w, type, slug);
    assert.deepEqual([...s].filter((k) => k.startsWith("event:")), [], `${type}:${slug}`);
    assert.deepEqual([...s].sort(), [...scopeOf(mines, type, slug)].sort());
    assert.doesNotThrow(() => systemPrompt(w, s));
  }
});

/// Подмена клиента базы: отдаёт строки по таблицам и, как PostgREST, оставляет только
/// запрошенные колонки (в том числе во вложенных связях).
function fakeDb(tables: Record<string, Record<string, unknown>[]>) {
  const cut = (row: Record<string, unknown>, cols: string): Record<string, unknown> => {
    const out: Record<string, unknown> = {};
    for (const part of cols.match(/\w+\([^)]*\)|[\w*]+/g)!) {
      const nested = part.match(/^(\w+)\(([^)]*)\)$/);
      if (part === "*") {
        for (const [k, v] of Object.entries(row)) if (!Array.isArray(v)) out[k] = v;
      } else if (nested) out[nested[1]] = (row[nested[1]] as Record<string, unknown>[]).map((r) => cut(r, nested[2]));
      else out[part] = row[part];
    }
    return out;
  };
  return {
    from: (table: string) => ({
      select: (cols = "*") => {
        const data = (tables[table] ?? []).map((r) => cut(r, cols));
        const done = Promise.resolve({ data, error: null });
        return { eq: () => ({ order: () => done, maybeSingle: () => Promise.resolve({ data: data[0] ?? null, error: null }) }) };
      },
    }),
  };
}

const base = { description: "", project_id: "w1" };
const rows = {
  projects: [{ id: "w1", title: "Копи", setting: "", tone: "", level_min: 1, level_max: 10 }],
  locations: [{ ...base, id: "L1", slug: "shtolnya_3", title: "Штольня №3", level_min: 1, level_max: 4, parent_id: null }],
  items: [{ id: "I1", slug: "klyuch", title: "Ключ", kind: "quest", rarity: "common", level: 1, damage: null, defense: null, price: 0 }],
  characters: [{
    ...base, id: "C1", slug: "slizen", title: "Слизень", role: "enemy", level: 2, hp: 12, attack: 5,
    location_id: "L1", loot: [],
  }],
  quests: [{
    ...base, id: "Q1", slug: "obval", title: "Обвал", giver_id: null, quest_rewards: [],
    quest_steps: [{ position: 1, kind: "event", character_id: null, item_id: null, location_id: null, event_id: "E1", amount: null }],
  }],
  events: [{
    id: "E1", slug: SLUG, title: "Засада у лебёдки", location_id: "L1",
    event_enemies: [{ character_id: "C1", amount: 3 }], event_items: [{ item_id: "I1" }],
  }],
};

test("событие: загрузка мира — строки базы со связями и шагом превращаются в вид со slug", async () => {
  const w = await loadWorld(fakeDb(rows), "w1");
  assert.deepEqual(w!.events, [{
    slug: SLUG, title: "Засада у лебёдки", location: "shtolnya_3",
    enemies: [{ enemy: "slizen", amount: 3 }], items: ["klyuch"],
  }]);
  assert.deepEqual(w!.quests[0].steps, [{ kind: "event", target: SLUG, amount: null }]);
});

test("событие: загрузка мира без событий — пустой список", async () => {
  const w = await loadWorld(fakeDb({ ...rows, events: [], quests: [] }), "w1");
  assert.deepEqual(w!.events, []);
});

test("событие: handle() на мире с событием и шагом event возвращает образцовый план", async () => {
  const { deps, calls } = scripted(withEventStep(ambush()), [planUse("t1", floodPlan)]);
  const r = await handle({
    project_id: "w1", scope: { type: "location", slug: "shtolnya_3" },
    request: "затопи её", attempt: 0, previous_plan: null, problems: [],
  }, deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.plan, floodPlan);
  assert.match(String(calls[0].system), /«Засада у лебёдки» \(zasada_u_lebedki\) в location:shtolnya_3/);
});
