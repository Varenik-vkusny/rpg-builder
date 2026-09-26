// Переходник петли ассистента ↔ API в формате OpenAI (Groq), без сети.
import assert from "node:assert/strict";
import { test } from "node:test";

import { ModelError } from "./gemini.ts";
import type { ModelCall } from "./handler.ts";
import { callOpenAI, fromOpenAI, toOpenAI } from "./openai_compat.ts";
import { TOOLS } from "./plan.ts";

const turn = {
  role: "assistant",
  content: null,
  tool_calls: [{ id: "c1", type: "function", function: { name: "propose_plan", arguments: "{\"summary\": \"x\", \"ops\": []}" } }],
};
const res = { choices: [{ message: turn, finish_reason: "tool_calls" }], usage: { prompt_tokens: 100, completion_tokens: 20 } };
const call: ModelCall = { system: "правила", tools: TOOLS, messages: [{ role: "user", content: "просьба" }] };

test("openai: вызов инструмента → tool_use с разобранными аргументами, токены", () => {
  const r = fromOpenAI(res);
  assert.equal(r.stop_reason, "tool_use");
  assert.deepEqual(r.usage, { input_tokens: 100, output_tokens: 20 });
  assert.deepEqual(r.content.filter((b) => b.type === "tool_use"), [
    { type: "tool_use", id: "c1", name: "propose_plan", input: { summary: "x", ops: [] } },
  ]);
});

test("openai: аргументы не JSON — уходят строкой (проверка схемы их отклонит)", () => {
  const bad = { choices: [{ message: { ...turn, tool_calls: [{ id: "c", function: { name: "propose_plan", arguments: "{оборвано" } }] } }] };
  assert.equal(fromOpenAI(bad).content[0].input, "{оборвано");
});

test("openai: запрос — система, просьба, ход модели как был, ответ инструмента с id; только план", () => {
  const r = fromOpenAI(res);
  const o = toOpenAI({
    ...call,
    messages: [
      { role: "user", content: "просьба" },
      { role: "assistant", content: r.content },
      { role: "user", content: [{ type: "tool_result", tool_use_id: "c1", is_error: true, content: "вне области" }] },
    ],
    only: "propose_plan",
  }, "m");
  assert.equal(o.model, "m");
  assert.deepEqual(o.messages.map((m: { role: string }) => m.role), ["system", "user", "assistant", "tool"]);
  assert.deepEqual(o.messages[2], turn);
  assert.deepEqual(o.messages[3], { role: "tool", tool_call_id: "c1", content: "ОШИБКА: вне области" });
  assert.deepEqual(o.tool_choice, { type: "function", function: { name: "propose_plan" } });
  // Разрешён только план — модель видит только его.
  assert.deepEqual(o.tools.map((t: { function: { name: string } }) => t.function.name), ["propose_plan"]);
  // Пустые поля плана — необязательные для провайдера; обязательные остаются.
  const loot = o.tools[0].function.parameters.properties.ops.items.anyOf.find(
    (k: { properties: { type: { enum: string[] } } }) => k.properties.type.enum[0] === "loot",
  );
  assert.deepEqual(loot.required, ["action", "type", "character", "item"]);
  assert.deepEqual(o.tools[0].function.parameters.required, ["summary", "ops"]);
  const free = toOpenAI(call, "m");
  assert.equal(free.tool_choice, "required");
  assert.equal(free.tools.length, 4);
});

test("openai: фильтр содержимого — отказ модели", () => {
  assert.equal(fromOpenAI({ choices: [{ message: {}, finish_reason: "content_filter" }] }).stop_reason, "refusal");
});

function fakeFetch(answers: { status: number; body: unknown; headers?: Record<string, string> }[]) {
  const seen: { url: string; model: string; auth: string }[] = [];
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    seen.push({
      url,
      model: JSON.parse(String(init.body)).model,
      auth: (init.headers as Record<string, string>).Authorization,
    });
    const a = answers[seen.length - 1];
    return new Response(JSON.stringify(a.body), { status: a.status, headers: a.headers });
  }) as typeof fetch;
  return seen;
}

test("openai: ключ в заголовке; 429 — пауза из retry-after и повтор; 503 — запасная модель", async () => {
  const seen = fakeFetch([
    { status: 429, body: {}, headers: { "retry-after": "7" } },
    { status: 503, body: {} },
    { status: 200, body: res },
  ]);
  const waited: number[] = [];
  const r = await callOpenAI("https://x/v1", "KEY", ["main", "spare"], call, async (ms) => { waited.push(ms); });
  assert.equal(r.stop_reason, "tool_use");
  assert.deepEqual(waited, [7000]);
  assert.deepEqual(seen.map((s) => s.model), ["main", "main", "spare"]);
  assert.equal(seen[0].auth, "Bearer KEY");
});

test("openai: ошибка без запасной — ModelError с кодом", async () => {
  fakeFetch([{ status: 401, body: { error: { message: "bad key" } } }]);
  await assert.rejects(callOpenAI("u", "k", ["m"], call, async () => {}), (e) => e instanceof ModelError && e.status === 401);
});

test("openai: 429 с паузой меньше 2 с — ждём 2 с (лимит токенов в минуту не успевает освободиться)", async () => {
  fakeFetch([
    { status: 429, body: {}, headers: { "retry-after": "0.3" } },
    { status: 429, body: {}, headers: { "retry-after": "1" } },
    { status: 200, body: res },
  ]);
  const waited: number[] = [];
  await callOpenAI("u", "k", ["m"], call, async (ms) => { waited.push(ms); });
  assert.deepEqual(waited, [2_000, 2_000]);
});

test("openai: у Mistral текст ошибки в message — доходит до автора, а не «Forbidden»", async () => {
  fakeFetch([{ status: 403, body: { message: "No access to model mistral-large-latest" } }]);
  await assert.rejects(
    callOpenAI("u", "k", ["m"], call, async () => {}),
    (e) => e instanceof ModelError && e.status === 403 && /No access to model/.test(e.message),
  );
});
