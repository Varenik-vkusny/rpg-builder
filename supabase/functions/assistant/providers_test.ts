// Выбор модели: только бесплатные из списка, ключ — только из секретов.
import assert from "node:assert/strict";
import { test } from "node:test";

import { pickModel } from "./providers.ts";

const env = (keys: Record<string, string>) => (name: string) => keys[name];

test("провайдер: модель из списка и ключ есть — вызов готов", () => {
  assert.equal(typeof pickModel("mistral:mistral-large-2512", env({ MISTRAL_API_KEY: "k" })), "function");
  assert.equal(typeof pickModel("groq:qwen/qwen3.8-27b", env({ GROQ_API_KEY: "k" })), "function");
});

test("провайдер: чужая модель или нет секрета — отказ словами", () => {
  assert.match(String(pickModel("mistral:gpt-5", env({ MISTRAL_API_KEY: "k" }))), /не из списка/);
  assert.match(String(pickModel("openai:gpt-5", env({}))), /не из списка/);
  assert.match(String(pickModel("zai:glm-4.7-flash", env({}))), /нет секрета ZAI_API_KEY/);
});

test("провайдер: без выбора — первый по порядку, у кого есть ключ; ни одного — отказ", () => {
  assert.equal(typeof pickModel(undefined, env({ GEMINI_API_KEY: "k" })), "function");
  assert.match(String(pickModel(undefined, env({}))), /нет ключа ни одного провайдера/);
});

/// Какую модель спросили: подменённый fetch запоминает поле model и отвечает планом.
function seenModels() {
  const seen: string[] = [];
  globalThis.fetch = (async (_url: string, init: RequestInit) => {
    seen.push(JSON.parse(String(init.body)).model);
    return new Response(JSON.stringify({ choices: [{ message: { role: "assistant", content: "ok" } }] }), { status: 200 });
  }) as typeof fetch;
  return seen;
}
const call = { system: "", tools: [], messages: [{ role: "user" as const, content: "x" }] };

test("запасная: выбранная модель первой, после двух ответов не по схеме (tier 1) — следующая по списку", async () => {
  const seen = seenModels();
  const m = pickModel("groq:openai/gpt-oss-20b", env({ GROQ_API_KEY: "k" }));
  if (typeof m === "string") throw new Error(m);
  await m(call);
  await m({ ...call, tier: 1 });
  await m({ ...call, tier: 9 });
  assert.deepEqual(seen, ["openai/gpt-oss-20b", "openai/gpt-oss-120b", "qwen/qwen3.8-27b"]);
});

test("провайдер: по умолчанию у Groq — gpt-oss-120b (владелец, 26.09)", async () => {
  const seen = seenModels();
  const m = pickModel(undefined, env({ GROQ_API_KEY: "k", GEMINI_API_KEY: "k" }));
  if (typeof m === "string") throw new Error(m);
  await m(call);
  assert.deepEqual(seen, ["openai/gpt-oss-120b"]);
});
