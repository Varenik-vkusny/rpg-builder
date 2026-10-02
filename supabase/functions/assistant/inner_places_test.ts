// Места внутри места (02.10, решение владельца): план описывает место заново, а места внутри
// него не трогает — сервер спрашивает автора «менять и их?». «Да» — план без них возвращается
// модели; «Нет» — план уходит как есть. Живые прогоны 02.10: модель дважды забыла штольню.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import { mines, op, planUse, scripted } from "./fixtures_test_data.ts";
import { handle } from "./handler.ts";
import { INNER_QUESTION_PREFIX, innerAnswer, innerPlacesMissed, innerQuestion, isServerQuestion, residentQuestion, unchangedQuestion } from "./inner_places.ts";
import { userPrompt } from "./prompt.ts";
import type { Plan } from "./plan.ts";
import type { World } from "./world.ts";
import { scopeOf } from "./world.ts";

const nested: World = {
  ...mines,
  locations: [
    { slug: "kopi", title: "Копи", description: "", level_min: 1, level_max: 6, parent: null },
    ...mines.locations.map((l) => (l.slug === "shtolnya_3" ? { ...l, parent: "kopi" } : l)),
  ],
};
const scope = () => scopeOf(nested, "location", "kopi");
const plan = (...ops: Plan["ops"]): Plan => ({ summary: "", ops });
const floodKopi = op({ type: "location", slug: "kopi", fields: { description: "затоплены" } });

test("места внутри: Копи описаны заново, штольня не тронута — пропущена", () => {
  const missed = innerPlacesMissed(plan(floodKopi), nested, scope());
  assert.deepEqual(missed.map((m) => m.slug), ["shtolnya_3"]);
});

test("места внутри: штольня в плане — ничего не пропущено", () => {
  const p = plan(floodKopi, op({ type: "location", slug: "shtolnya_3", fields: { description: "по пояс" } }));
  assert.deepEqual(innerPlacesMissed(p, nested, scope()), []);
});

test("места внутри: Копи только переименованы — не спрашиваем", () => {
  const p = plan(op({ type: "location", slug: "kopi", fields: { title: "Старые копи" } }));
  assert.deepEqual(innerPlacesMissed(p, nested, scope()), []);
});

test("места внутри: вопрос автору называет места, первым — «да»", () => {
  const q = innerQuestion(innerPlacesMissed(plan(floodKopi), nested, scope()), nested);
  assert.ok(q.question.startsWith(INNER_QUESTION_PREFIX));
  assert.match(q.question, /«Штольня №3»/);
  assert.match(q.question, /«Копи»/);
  assert.equal(q.options.length, 2);
  assert.match(q.options[0].label, /^Да/);
});

test("места внутри: ответ автора читается — да, нет, не спрашивали", () => {
  const q = innerQuestion(innerPlacesMissed(plan(floodKopi), nested, scope()), nested);
  assert.equal(innerAnswer([{ question: q.question, answer: q.options[0].label }]), "yes");
  assert.equal(innerAnswer([{ question: q.question, answer: q.options[1].label }]), "no");
  assert.equal(innerAnswer([{ question: "Что делать со слизнем?", answer: "Удалить" }]), null);
});

// Петля целиком: подменённая модель забывает штольню.
const req = (answers: { question: string; answer: string }[] = []) => ({
  project_id: "w1",
  scope: { type: "location", slug: "kopi" },
  request: "затопи копи",
  attempt: 0,
  previous_plan: null,
  problems: [],
  answers,
});
const withShaft = plan(floodKopi, op({ type: "location", slug: "shtolnya_3", fields: { description: "по пояс" } }));
const askedText = () => innerQuestion(innerPlacesMissed(plan(floodKopi), nested, scope()), nested).question;

test("места внутри: забыл штольню — автору уходит вопрос, а не план", async () => {
  const { deps } = scripted(nested, [planUse("t1", plan(floodKopi))]);
  const r = await handle(req(), deps);
  assert.equal(r.status, 200);
  assert.equal(r.body.plan, undefined);
  assert.match(r.body.question.question, /«Штольня №3»/);
});

test("места внутри: автор сказал «да» — план без штольни возвращается модели", async () => {
  const { deps, calls } = scripted(nested, [planUse("t1", plan(floodKopi)), planUse("t2", withShaft)]);
  const r = await handle(req([{ question: askedText(), answer: "Да, и их тоже" }]), deps);
  assert.deepEqual(r.body.plan.ops.map((o: { slug: string }) => o.slug), ["kopi", "shtolnya_3"]);
  assert.match(JSON.stringify(calls[1].messages.at(-1)), /location:shtolnya_3/);
});

test("места внутри: автор сказал «нет» — план уходит без штольни", async () => {
  const { deps } = scripted(nested, [planUse("t1", plan(floodKopi))]);
  const r = await handle(req([{ question: askedText(), answer: "Нет, только «Копи»" }]), deps);
  assert.deepEqual(r.body.plan.ops.map((o: { slug: string }) => o.slug), ["kopi"]);
});

// Удаление жителя (02.10, решение владельца): модель удалила слизня, спросив автора только про
// штольню. Сервер спрашивает сам, если ни один вопрос не называл жителя.
const delSlime = op({ action: "delete", type: "character", slug: "slizen" });
const shaftAnswer = { question: "", answer: "Да, и их тоже" };

test("жители: удаление без вопроса о слизне — сервер спрашивает «удалить Слизня?»", async () => {
  const { deps } = scripted(nested, [planUse("t1", plan(...withShaft.ops, delSlime))]);
  const r = await handle(req([{ ...shaftAnswer, question: askedText() }]), deps);
  assert.equal(r.body.plan, undefined);
  assert.match(r.body.question.question, /слизень»/i);
  assert.match(r.body.question.options[0].label, /^Да/);
});

test("жители: модель сама спрашивала про слизня — сервер не переспрашивает", async () => {
  const { deps } = scripted(nested, [planUse("t1", plan(...withShaft.ops, delSlime))]);
  const r = await handle(req([{ question: "Что делать с Пепельным слизнем?", answer: "Удалить" }]), deps);
  assert.equal(r.body.question, undefined);
  assert.equal(r.body.plan.ops.length, 3);
});

test("жители: автор не разрешил удалять — план возвращается модели", async () => {
  const { deps, calls } = scripted(nested, [
    planUse("t1", plan(...withShaft.ops, delSlime)),
    planUse("t2", withShaft),
  ]);
  const q = residentQuestion([{ slug: "slizen", title: "Пепельный слизень" }]);
  const r = await handle(req([{ question: q.question, answer: q.options[1].label }]), deps);
  assert.deepEqual(r.body.plan.ops.map((o: { slug: string }) => o.slug), ["kopi", "shtolnya_3"]);
  assert.match(JSON.stringify(calls[1].messages.at(-1)), /не разрешил/);
});

test("жители: серверные вопросы не съедают 2 вопроса модели", async () => {
  const q = residentQuestion([{ slug: "slizen", title: "Пепельный слизень" }]);
  const { deps } = scripted(nested, [planUse("t1", withShaft)]);
  const r = await handle(req([
    { question: "Вопрос модели 1", answer: "а" },
    { question: "Вопрос модели 2", answer: "б" },
    { question: askedText(), answer: "Да, и их тоже" },
    { question: q.question, answer: q.options[0].label },
  ]), deps);
  assert.equal(r.status, 200);
});

// Ревью 02.10: «спрошен» — только если вопрос называет каждое слово имени; вопрос сервера
// про места внутри не в счёт; второй серверный вопрос о жителях не задаётся.
const withHost: World = {
  ...nested,
  characters: [
    ...nested.characters,
    { slug: "hozyain", title: "Хозяин копи", description: "", role: "npc", level: 1, hp: 10, attack: 0, location: "kopi", loot: [] },
  ],
};
const delHost = op({ action: "delete", type: "character", slug: "hozyain" });

test("жители: «Хозяин копи» не считается спрошенным из-за вопроса про «Копи»", async () => {
  const { deps } = scripted(withHost, [planUse("t1", plan(...withShaft.ops, delHost))]);
  const r = await handle(req([{ question: askedText(), answer: "Да, и их тоже" }]), deps);
  assert.match(r.body.question?.question ?? "", /Хозяин копи/);
});

test("жители: второго вопроса о жителях нет — план возвращается модели", async () => {
  const q = residentQuestion([{ slug: "slizen", title: "Пепельный слизень" }]);
  const { deps, calls } = scripted(withHost, [
    planUse("t1", plan(...withShaft.ops, delSlime, delHost)),
    planUse("t2", plan(...withShaft.ops, delSlime)),
  ]);
  const r = await handle(req([{ question: q.question, answer: q.options[0].label }]), deps);
  assert.equal(r.status, 200);
  assert.equal(r.body.question, undefined);
  assert.deepEqual(r.body.plan.ops.map((o: { slug: string }) => o.slug), ["kopi", "shtolnya_3", "slizen"]);
  assert.match(JSON.stringify(calls[1].messages.at(-1)), /Хозяин копи/);
});

// Живой прогон 02.10 v38 (test/fixtures/kopi_flood_2026-10-02_v38.json): модель спросила про
// слизня и не тронула ни одного места. Решение владельца: сервер спрашивает «<место> в плане
// не изменено — изменить описание?».
const v38 = JSON.parse(readFileSync(new URL("../../../test/fixtures/kopi_flood_2026-10-02_v38.json", import.meta.url), "utf8"));
const v38Plan = (): Plan => ({ summary: v38.plan.summary, ops: v38.plan.ops.map(op) });

test("место не изменено: прогон v38 — сервер спрашивает «Копи в плане не изменено»", async () => {
  const { deps } = scripted(nested, [planUse("t1", v38Plan())]);
  const r = await handle(req(v38.answers), deps);
  assert.equal(r.body.plan, undefined);
  assert.match(r.body.question?.question ?? "", /«Копи» в плане не изменено — изменить описание\?/);
});

test("место не изменено: «да» — план без описания Копи возвращается модели", async () => {
  const { deps, calls } = scripted(nested, [
    planUse("t1", v38Plan()),
    planUse("t2", plan(floodKopi, op({ type: "location", slug: "shtolnya_3", fields: { description: "по пояс" } }))),
  ]);
  const q = unchangedQuestion(nested.locations[0]);
  const r = await handle(req([...v38.answers, { question: q.question, answer: q.options[0].label }]), deps);
  assert.match(JSON.stringify(calls[1].messages.at(-1)), /location:kopi/);
  assert.ok(r.body.plan.ops.some((o: { slug: string }) => o.slug === "kopi"));
});

test("место не изменено: «нет» — план уходит как есть", async () => {
  const { deps } = scripted(nested, [planUse("t1", v38Plan())]);
  const q = unchangedQuestion(nested.locations[0]);
  // В тестовом мире слизень — «Пепельный слизень»: на вопрос сервера о нём автор тоже ответил.
  const del = residentQuestion([{ slug: "slizen", title: "Пепельный слизень" }]);
  const r = await handle(req([
    ...v38.answers,
    { question: q.question, answer: q.options[1].label },
    { question: del.question, answer: del.options[0].label },
  ]), deps);
  assert.equal(r.body.question, undefined);
  assert.equal(r.body.plan.ops.length, 3);
});

test("подсказка: просьба про место — его описание первой операцией", () => {
  assert.match(userPrompt({ ...req(), attempt: 0 } as never), /location:kopi: первой операцией плана измени его description/);
});

test("место не изменено: просьба не называет места — не спрашиваем", async () => {
  const { deps } = scripted(nested, [planUse("t1", plan(op({ type: "character", slug: "slizen", fields: { attack: 4 } })))]);
  const r = await handle({ ...req(), request: "уменьши атаку слизня" }, deps);
  assert.equal(r.body.question, undefined);
  assert.equal(r.body.plan.ops.length, 1);
});

test("место не изменено: «скопируй», «накопи» — не про Копи", async () => {
  for (const request of ["скопируй слизня в рынок", "накопи слизням опыта"]) {
    const { deps } = scripted(nested, [planUse("t1", plan(op({ type: "character", slug: "slizen", fields: { attack: 4 } })))]);
    const r = await handle({ ...req(), request }, deps);
    assert.equal(r.body.question, undefined, request);
  }
});

test("свой вопрос сервер узнаёт только по началу — модель не протащит вопрос мимо лимита", () => {
  assert.ok(isServerQuestion(unchangedQuestion(nested.locations[0]).question));
  assert.ok(!isServerQuestion("Что делать: «Копи» в плане не изменено — согласны?"));
  assert.ok(!isServerQuestion("Вопрос модели. Места внутри тоже менять?"));
});
