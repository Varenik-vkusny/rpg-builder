// Срез В: сбой модели — повтор, потом запасная; ответ укладывается в TOTAL_MS (120 с).
import assert from "node:assert/strict";
import { test } from "node:test";

import { mines, scripted, toolUse } from "./fixtures_test_data.ts";
import type { ModelCall } from "./handler.ts";
import { handle, MAX_TURNS, TOTAL_MS } from "./handler.ts";
import { CALL_TIMEOUT_MS, ModelError, postModel } from "./model_http.ts";

type Answer = { status: number; body?: unknown; headers?: Record<string, string> } | "timeout";

/// Подменённый провайдер: отвечает по списку, запоминает модель и срок ожидания каждого вызова.
function provider(answers: Answer[], extra: { deadline?: number; now?: () => number } = {}) {
  const seen: string[] = [];
  const waited: number[] = [];
  const run = postModel({
    models: ["main", "spare"],
    send: async (model) => {
      seen.push(model);
      const a = answers[seen.length - 1];
      if (a === "timeout") throw new DOMException("timeout", "TimeoutError");
      return new Response(JSON.stringify(a.body ?? {}), { status: a.status, headers: a.headers });
    },
    retryAfterMs: (r) => {
      const s = parseFloat(r.headers.get("retry-after") ?? "");
      return Number.isFinite(s) ? s * 1000 : null;
    },
    fallbackOn: [404],
    wait: async (ms) => { waited.push(ms); },
    ...extra,
  });
  return { run, seen, waited };
}
const ok = { status: 200, body: { ok: true } };

test("повтор: 400 (кривой вызов инструмента) — повтор на той же, потом запасная", async () => {
  const p = provider([{ status: 400 }, { status: 400 }, ok]);
  assert.deepEqual(await p.run, { ok: true });
  assert.deepEqual(p.seen, ["main", "main", "spare"]);
});

test("повтор: таймаут — повтор на той же, потом запасная", async () => {
  const p = provider(["timeout", "timeout", ok]);
  assert.deepEqual(await p.run, { ok: true });
  assert.deepEqual(p.seen, ["main", "main", "spare"]);
});

test("повтор: 503 один раз — вторая попытка на той же модели отвечает", async () => {
  const p = provider([{ status: 503 }, ok]);
  assert.deepEqual(await p.run, { ok: true });
  assert.deepEqual(p.seen, ["main", "main"]);
});

test("повтор: суточный лимит (429, ждать 12 минут) — не ждём, сразу запасная", async () => {
  const p = provider([{ status: 429, headers: { "retry-after": "769" } }, ok]);
  assert.deepEqual(await p.run, { ok: true });
  assert.deepEqual(p.seen, ["main", "spare"]);
  assert.deepEqual(p.waited, []);
});

test("повтор: не ответила ни одна — последняя ошибка с кодом и текстом провайдера", async () => {
  const p = provider([{ status: 400 }, { status: 400 }, "timeout", "timeout"]);
  await assert.rejects(p.run, (e) => e instanceof ModelError && e.status === 504 && /spare: нет ответа за 60 с/.test(e.message));
});

test("повтор: время ответа кончилось — 504 без нового вызова модели", async () => {
  const p = provider([ok], { deadline: 1_000, now: () => 1_000 });
  await assert.rejects(p.run, (e) => e instanceof ModelError && e.status === 504);
  assert.deepEqual(p.seen, []);
});

test("лимит времени: один вызов ждём не дольше 60 с, весь ответ — 120 с", () => {
  assert.equal(CALL_TIMEOUT_MS, 60_000);
  assert.equal(TOTAL_MS, 120_000);
});

const ask = {
  project_id: "w1",
  scope: { type: "location", slug: "shtolnya_3" },
  request: "затопи её",
  attempt: 0,
  previous_plan: null,
  problems: [],
  answers: [{ question: "q", answer: "a" }, { question: "q", answer: "a" }],
};
const bad = { summary: "x", ops: [{ action: "explode", type: "location", slug: "shtolnya_3" }] };

test("запасная: два ответа не по схеме подряд — следующий ход у запасной модели", async () => {
  const { deps, calls } = scripted(mines, Array.from({ length: MAX_TURNS }, (_, i) => toolUse(`t${i}`, "propose_plan", bad)));
  const r = await handle(ask, deps);
  assert.equal(r.status, 502);
  assert.deepEqual(calls.map((c: ModelCall) => c.tier ?? 0), [0, 0, 1, 1]);
  assert.ok((r.body.trace as string[]).includes("дальше запасная модель"));
});

test("лимит времени: ответ не уложился в 120 с — 504 с тем, что модель успела", async () => {
  let t = 0;
  const { deps, calls } = scripted(mines, Array.from({ length: MAX_TURNS }, (_, i) => toolUse(`t${i}`, "propose_plan", bad)));
  // Каждый ход модели — 70 с: после второго хода время вышло.
  const slow = { ...deps, now: () => t, callModel: async (c: ModelCall) => { t += 70_000; return deps.callModel(c); } };
  const r = await handle(ask, slow);
  assert.equal(r.status, 504);
  assert.match(String(r.body.error), /не уложилась в 120 с: план не по схеме/);
  assert.equal(calls.length, 2);
  assert.equal(calls[0].deadline, TOTAL_MS);
});
