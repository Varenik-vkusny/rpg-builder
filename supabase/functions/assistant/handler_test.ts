// Серверная функция ассистента на подменённой модели. Запуск: node --test supabase/functions/
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { floodPlan, mines, op, planUse, scripted, toolUse } from "./fixtures_test_data.ts";
import { handle, MAX_FIXES, MAX_TURNS } from "./handler.ts";
import type { Plan } from "./plan.ts";
import { outOfScope, TOOLS } from "./plan.ts";
import { objectsByKey, scopeOf } from "./world.ts";

const ask = (extra: Record<string, unknown> = {}) => ({
  project_id: "w1",
  scope: { type: "location", slug: "shtolnya_3" },
  request: "затопи её, слизни там жить не могут",
  attempt: 0,
  previous_plan: null,
  problems: [],
  ...extra,
});

test("план: модель читает область и возвращает план, токены сложены", async () => {
  const { deps, calls } = scripted(mines, [
    toolUse("t1", "read_object", { type: "location", slug: "shtolnya_3" }),
    planUse("t2", floodPlan),
  ]);
  const r = await handle(ask(), deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.plan, floodPlan);
  assert.deepEqual(r.body.usage, { input_tokens: 200, output_tokens: 40 });
  // Результат чтения ушёл модели вторым ходом.
  const toolResult = (calls[1].messages[2].content as { content: string }[])[0].content;
  assert.match(toolResult, /обвалившаяся выработка/);
});

test("план: у модели только чтение, вопрос автору и propose_plan", () => {
  assert.deepEqual(TOOLS.map((t) => t.name), ["find_in_scope", "read_object", "ask_author", "propose_plan"]);
});

test("план: область — объект и связанное до двух связей", async () => {
  const { deps, calls } = scripted(mines, [planUse("t1", floodPlan)]);
  await handle(ask(), deps);
  const system = calls[0].system;
  // 1 связь: слизень; 2 связи: ключ (добыча слизня), квест (убить слизня).
  for (const k of ["location:shtolnya_3", "character:slizen", "item:klyuch", "quest:obval"]) {
    assert.match(system, new RegExp(k), k);
  }
  // 3 связи (бригадир — через квест) и несвязанное — вне области.
  for (const k of ["character:brigadir", "location:rynok", "character:torgovka", "item:yabloko"]) {
    assert.doesNotMatch(system, new RegExp(k), k);
  }
});

test("план: read_object вне области не отдаёт объект", async () => {
  const { deps, calls } = scripted(mines, [
    toolUse("t1", "read_object", { type: "location", slug: "rynok" }),
    planUse("t2", floodPlan),
  ]);
  await handle(ask(), deps);
  const toolResult = (calls[1].messages[2].content as { content: string }[])[0].content;
  assert.match(toolResult, /вне области/);
  assert.doesNotMatch(toolResult, /Рынок/);
});

test("план: модель без инструмента получает напоминание, без плана за MAX_TURNS ходов — 502", async () => {
  const text = { stop_reason: "end_turn", content: [{ type: "text", text: "думаю" }], usage: { input_tokens: 1, output_tokens: 1 } };
  const { deps, calls } = scripted(mines, Array.from({ length: MAX_TURNS }, () => structuredClone(text)));
  const r = await handle(ask(), deps);
  assert.equal(r.status, 502);
  assert.equal(calls.length, MAX_TURNS);
  assert.match(String(calls[1].messages[2].content), /propose_plan/);
});

test("план: отказ модели — 502, план не возвращается", async () => {
  const { deps } = scripted(mines, [{ stop_reason: "refusal", content: [], usage: { input_tokens: 5, output_tokens: 0 } }]);
  const r = await handle(ask(), deps);
  assert.equal(r.status, 502);
  assert.equal(r.body.plan, undefined);
});

test("план: чужой или несуществующий мир — 404", async () => {
  const { deps, calls } = scripted(null, []);
  const r = await handle(ask(), deps);
  assert.equal(r.status, 404);
  assert.equal(calls.length, 0);
});

test("план: объекта области нет в мире — 404", async () => {
  const { deps } = scripted(mines, []);
  const r = await handle(ask({ scope: { type: "quest", slug: "net_takogo" } }), deps);
  assert.equal(r.status, 404);
});

for (const [name, bad] of [
  ["пустая просьба", { request: "  " }],
  ["область-предмет", { scope: { type: "item", slug: "klyuch" } }],
  ["без мира", { project_id: undefined }],
] as const) {
  test(`план: ${name} — 400 без вызова модели`, async () => {
    const { deps, calls } = scripted(mines, []);
    const r = await handle(ask(bad), deps);
    assert.equal(r.status, 400);
    assert.equal(calls.length, 0);
  });
}

test("исправлени: попытка сверх двух — 400 без вызова модели", async () => {
  const { deps, calls } = scripted(mines, []);
  const r = await handle(ask({ attempt: MAX_FIXES + 1, previous_plan: floodPlan, problems: ["x"] }), deps);
  assert.equal(r.status, 400);
  assert.equal(calls.length, 0);
});

test("исправлени: модель получает прошлый план и список проблем", async () => {
  const { deps, calls } = scripted(mines, [planUse("t1", floodPlan)]);
  const r = await handle(
    ask({ attempt: 1, previous_plan: floodPlan, problems: ["«Утопленник»: атака 14 выше потолка 10 (ур. 3)"] }),
    deps,
  );
  assert.equal(r.status, 200);
  const prompt = String(calls[0].messages[0].content);
  assert.match(prompt, /атака 14 выше потолка 10/);
  assert.match(prompt, /"attack":14/);
});

test("план: общий образец flood_plan.json совпадает с планом тестов функции", () => {
  // Тот же файл читают тесты приложения (test/assistant_fixtures.dart) — форматы не разойдутся.
  const shared = JSON.parse(readFileSync(new URL("./flood_plan.json", import.meta.url), "utf8"));
  assert.deepEqual(shared, floodPlan);
});

/// План затопления плюс одна операция вне области штольни.
const withOutside = (extra: Plan["ops"][number]): Plan => ({ ...floodPlan, ops: [...floodPlan.ops, extra] });
const shaftScope = () => scopeOf(mines, "location", "shtolnya_3");

test("вне области: план в границах и созданное планом — можно", () => {
  // Утопленника создаёт сам план — упоминать его в добыче и шаге квеста можно.
  assert.deepEqual(outOfScope(floodPlan, shaftScope()), []);
});

for (const [name, extra, what] of [
  ["изменить объект вне области", op({ type: "location", slug: "rynok", fields: { description: "x" } }), "location:rynok"],
  ["удалить объект вне области", op({ action: "delete", type: "item", slug: "yabloko" }), "item:yabloko"],
  ["сослаться на объект вне области", op({ type: "character", slug: "slizen", fields: { location: "rynok" } }), "location:rynok"],
  ["добыча предметом вне области", op({ action: "create", type: "loot", character: "slizen", item: "yabloko", fields: { chance: 5 } }), "item:yabloko"],
  ["цель шага без вида шага", op({ type: "quest_step", quest: "obval", position: 1, fields: { target: "slizen" } }), "шаг-без-вида:slizen"],
  ["шаг квеста с целью вне области", op({ type: "quest_step", quest: "obval", position: 1, fields: { step_kind: "talk", target: "torgovka" } }), "character:torgovka"],
] as const) {
  test(`вне области: ${name} — отклоняется`, () => {
    const bad = outOfScope(withOutside(extra), shaftScope());
    assert.equal(bad.length, 1, bad.join("; "));
    assert.match(bad[0], new RegExp(`операция 6 .*${what}`));
  });
}

test("вне области: функция отклоняет план, модель исправляет — уходит исправленный", async () => {
  const bad = withOutside(op({ type: "location", slug: "rynok", fields: { description: "x" } }));
  const { deps, calls } = scripted(mines, [planUse("t1", bad), planUse("t2", floodPlan)]);
  const r = await handle(ask(), deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.plan, floodPlan);
  const rejected = (calls[1].messages[2].content as { is_error: boolean; content: string }[])[0];
  assert.equal(rejected.is_error, true);
  assert.match(rejected.content, /location:rynok вне области/);
});

test("вне области: второй раз вне области — 422, плана нет", async () => {
  const bad = withOutside(op({ action: "delete", type: "item", slug: "yabloko" }));
  const { deps, calls } = scripted(mines, [planUse("t1", bad), planUse("t2", bad)]);
  const r = await handle(ask(), deps);
  assert.equal(r.status, 422);
  assert.equal(r.body.plan, undefined);
  assert.equal(calls.length, 2);
  assert.match(String(r.body.out_of_scope), /item:yabloko/);
});

test("план: данные области сразу в подсказке, чтения нет — только вопрос автору или план", async () => {
  const { deps, calls } = scripted(mines, [planUse("p", floodPlan)]);
  const r = await handle(ask(), deps);
  assert.equal(r.status, 200);
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].tools.map((t) => t.name), ["ask_author", "propose_plan"]);
  // Поля объектов области — в подсказке; объект вне области — нет.
  assert.match(calls[0].system, /location:shtolnya_3: \{.*обвалившаяся выработка/);
  assert.match(calls[0].system, /character:slizen: \{.*"attack":5/);
  assert.doesNotMatch(calls[0].system, /location:rynok:/);
});

const question = {
  question: "Вы просили атаку 14, но у врага 3 уровня потолок 10.",
  options: [
    { label: "Поставить 10", description: "баланс в норме" },
    { label: "Оставить 14", description: "будет предупреждение" },
  ],
};

test("вопрос: просьба спорит с правилами — модель спрашивает, вопрос уходит автору, плана нет", async () => {
  const { deps } = scripted(mines, [toolUse("q", "ask_author", question)]);
  const r = await handle(ask(), deps);
  assert.equal(r.status, 200);
  assert.deepEqual(r.body.question, question);
  assert.equal(r.body.plan, undefined);
});

test("вопрос: вариантов не 2–4 — модель получает ошибку и спрашивает заново", async () => {
  const one = { ...question, options: question.options.slice(0, 1) };
  const { deps, calls } = scripted(mines, [toolUse("q1", "ask_author", one), toolUse("q2", "ask_author", question)]);
  const r = await handle(ask(), deps);
  assert.deepEqual(r.body.question, question);
  const reply = (calls[1].messages[2].content as { is_error: boolean; content: string }[])[0];
  assert.equal(reply.is_error, true);
  assert.match(reply.content, /вариантов 1, нужно 2–4/);
});

test("вопрос: ответы автора — в просьбе к модели; после двух вопросов и в исправлении — только план", async () => {
  const answers = [{ question: question.question, answer: "Поставить 10" }];
  const once = scripted(mines, [planUse("p", floodPlan)]);
  await handle(ask({ answers }), once.deps);
  assert.match(String(once.calls[0].messages[0].content), /Ответ: Поставить 10/);
  assert.deepEqual(once.calls[0].tools.map((t) => t.name), ["ask_author", "propose_plan"]);

  const twice = scripted(mines, [planUse("p", floodPlan)]);
  await handle(ask({ answers: [...answers, ...answers] }), twice.deps);
  assert.deepEqual(twice.calls[0].tools.map((t) => t.name), ["propose_plan"]);
  assert.equal(twice.calls[0].only, "propose_plan");

  const fix = scripted(mines, [planUse("p", floodPlan)]);
  await handle(ask({ attempt: 1, previous_plan: floodPlan, problems: ["x"] }), fix.deps);
  assert.deepEqual(fix.calls[0].tools.map((t) => t.name), ["propose_plan"]);
});

test("вопрос: кривые ответы и больше двух — 400", async () => {
  const { deps } = scripted(mines, []);
  assert.equal((await handle(ask({ answers: [{ question: "q", answer: " " }] }), deps)).status, 400);
  const a = { question: "q", answer: "a" };
  assert.equal((await handle(ask({ answers: [a, a, a] }), deps)).status, 400);
});

test("вне области: не указан slug и опечатка в slug — модель узнаёт точную причину", () => {
  const ops = floodPlan.ops;
  const noSlug = { ...ops[0], slug: null };
  const typo = { ...ops[3], character: "utoplenik_3" };
  const world = new Set(objectsByKey(mines).keys());
  const bad = outOfScope({ summary: "", ops: [noSlug, typo] }, shaftScope(), world);
  assert.equal(bad.length, 2, bad.join("\n"));
  assert.match(bad[0], /операция 1 .*не указан slug \(location\)/);
  assert.match(bad[1], /операция 2 .*character:utoplenik_3 нет в мире, и план его не создаёт/);
});
