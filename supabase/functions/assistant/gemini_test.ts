// Переходник петли ассистента ↔ Gemini generateContent (без сети).
import assert from "node:assert/strict";
import { test } from "node:test";

import { callGemini, fromGemini, ModelError, toGemini } from "./gemini.ts";
import { RATE_WAITS } from "./model_http.ts";
import type { ModelCall } from "./handler.ts";
import { TOOLS } from "./plan.ts";

const turn = {
  role: "model",
  parts: [
    { text: "думаю", thought: true },
    { functionCall: { id: "fc1", name: "read_object", args: { type: "location", slug: "shtolnya_3" } }, thoughtSignature: "SIG" },
  ],
};
const res = { candidates: [{ content: turn, finishReason: "STOP" }], usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 20, thoughtsTokenCount: 5 } };

test("gemini: вызов инструмента → tool_use, токены с мыслями, мысли не в тексте", () => {
  const r = fromGemini(res);
  assert.equal(r.stop_reason, "tool_use");
  assert.deepEqual(r.usage, { input_tokens: 100, output_tokens: 25 });
  const uses = r.content.filter((b) => b.type === "tool_use");
  assert.deepEqual(uses, [{ type: "tool_use", id: "fc1", name: "read_object", input: { type: "location", slug: "shtolnya_3" } }]);
  assert.equal(r.content.some((b) => b.type === "text"), false);
});

test("gemini: ход модели уходит обратно как был — с подписью мысли; ответ инструмента с id и именем", () => {
  const r = fromGemini(res);
  const call: ModelCall = {
    system: "правила",
    tools: TOOLS,
    messages: [
      { role: "user", content: "просьба" },
      { role: "assistant", content: r.content },
      { role: "user", content: [{ type: "tool_result", tool_use_id: "fc1", content: "{\"title\":\"Штольня\"}" }] },
    ],
  };
  const g = toGemini(call);
  assert.deepEqual(g.systemInstruction, { parts: [{ text: "правила" }] });
  assert.deepEqual(g.contents[0], { role: "user", parts: [{ text: "просьба" }] });
  assert.deepEqual(g.contents[1], turn);
  assert.deepEqual(g.contents[2].parts[0].functionResponse, { id: "fc1", name: "read_object", response: { result: "{\"title\":\"Штольня\"}" } });
  assert.deepEqual(g.toolConfig, { functionCallingConfig: { mode: "ANY" } });
  assert.deepEqual(g.tools[0].functionDeclarations.map((f: { name: string }) => f.name), ["find_in_scope", "read_object", "ask_author", "propose_plan"]);
  assert.equal(g.tools[0].functionDeclarations[3].parametersJsonSchema, TOOLS[3].input_schema);
});

test("gemini: ошибка инструмента уходит как error; вызов без id — без id и обратно", () => {
  const noId = fromGemini({ candidates: [{ content: { role: "model", parts: [{ functionCall: { name: "propose_plan", args: {} } }] } }] });
  const use = noId.content.find((b) => b.type === "tool_use")!;
  const g = toGemini({
    system: "",
    tools: TOOLS,
    messages: [
      { role: "user", content: "x" },
      { role: "assistant", content: noId.content },
      { role: "user", content: [{ type: "tool_result", tool_use_id: use.id, is_error: true, content: "вне области" }] },
    ],
  });
  assert.deepEqual(g.contents[2].parts[0].functionResponse, { name: "propose_plan", response: { error: "вне области" } });
});

test("gemini: блокировка безопасностью — отказ модели", () => {
  assert.equal(fromGemini({ candidates: [{ finishReason: "SAFETY" }] }).stop_reason, "refusal");
  assert.equal(fromGemini({ promptFeedback: { blockReason: "OTHER" } }).stop_reason, "refusal");
});

test("gemini: ход только с одним инструментом — allowedFunctionNames", () => {
  const g = toGemini({ system: "", tools: TOOLS, messages: [{ role: "user", content: "x" }], only: "propose_plan" });
  assert.deepEqual(g.toolConfig, { functionCallingConfig: { mode: "ANY", allowedFunctionNames: ["propose_plan"] } });
});

/// Подменённый fetch: ответы по очереди, запоминает число вызовов.
function fakeFetch(answers: { status: number; body: unknown }[]) {
  let n = 0;
  globalThis.fetch = (async () => {
    const a = answers[n++];
    return new Response(JSON.stringify(a.body), { status: a.status });
  }) as typeof fetch;
  return () => n;
}
const call: ModelCall = { system: "", tools: TOOLS, messages: [{ role: "user", content: "x" }] };
const limit = { error: { message: "quota", details: [{ retryDelay: "12s" }] } };

test("gemini: лимит в минуту (429) — ждём сколько просит Gemini и пробуем ещё раз", async () => {
  const calls = fakeFetch([{ status: 429, body: limit }, { status: 200, body: res }]);
  const waited: number[] = [];
  const r = await callGemini("k", ["m"], call, async (ms) => { waited.push(ms); });
  assert.equal(r.stop_reason, "tool_use");
  assert.deepEqual(waited, [12_000]);
  assert.equal(calls(), 2);
});

test("gemini: 429 больше RATE_WAITS раз подряд — ошибка модели, дальше не ждём", async () => {
  const calls = fakeFetch([...Array(RATE_WAITS + 1).fill({ status: 429, body: limit }), { status: 200, body: res }]);
  await assert.rejects(callGemini("k", ["m"], call, async () => {}), (e) => e instanceof ModelError && e.status === 429);
  assert.equal(calls(), RATE_WAITS + 1);
});

test("gemini: основная модель перегружена (503) — повтор, потом отвечает запасная", async () => {
  const urls: string[] = [];
  let n = 0;
  const answers = [503, 503].map((status) => ({ status, body: { error: { message: "high demand" } } as unknown })).concat([{ status: 200, body: res }]);
  globalThis.fetch = (async (url: string) => {
    urls.push(url);
    const a = answers[n++];
    return new Response(JSON.stringify(a.body), { status: a.status });
  }) as typeof fetch;
  const r = await callGemini("k", ["main", "spare"], call, async () => {});
  assert.equal(r.stop_reason, "tool_use");
  assert.deepEqual(urls.map((u) => u.split("/models/")[1].split(":")[0]), ["main", "main", "spare"]);
});

test("gemini: перегружены все модели — ошибка 503", async () => {
  fakeFetch(Array(4).fill({ status: 503, body: {} }));
  await assert.rejects(callGemini("k", ["a", "b"], call, async () => {}), (e) => e instanceof ModelError && e.status === 503);
});
