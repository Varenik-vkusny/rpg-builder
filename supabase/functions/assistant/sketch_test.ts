// Скетч (4.4): фото рисунка уходит модели с картинками вместе с просьбой, без сети.
import assert from "node:assert/strict";
import { test } from "node:test";

import { floodPlan, mines, planUse, scripted } from "./fixtures_test_data.ts";
import { handle, MAX_IMAGE_CHARS, parseRequest } from "./handler.ts";
import { toOpenAI } from "./openai_compat.ts";
import { pickModel } from "./providers.ts";

const sketch = { mime: "image/jpeg", data: "AAAA" };
const ask = (extra: Record<string, unknown> = {}) => ({
  project_id: "w1",
  scope: { type: "location", slug: "shtolnya_3" },
  request: "Создай персонажа по скетчу",
  attempt: 0,
  previous_plan: null,
  problems: [],
  ...extra,
});

test("скетч: картинка — jpeg, png или webp в base64, не больше предела; без картинки — null", () => {
  const ok = parseRequest(ask({ image: sketch }));
  assert.deepEqual(typeof ok === "string" ? ok : ok.image, sketch);
  const none = parseRequest(ask());
  assert.equal(typeof none === "string" ? none : none.image, null);
  assert.match(String(parseRequest(ask({ image: { mime: "image/gif", data: "AAAA" } }))), /картинка/);
  assert.match(String(parseRequest(ask({ image: { mime: "image/jpeg", data: "" } }))), /картинка/);
  const big = "A".repeat(MAX_IMAGE_CHARS + 1);
  assert.match(String(parseRequest(ask({ image: { mime: "image/jpeg", data: big } }))), /больше/);
});

test("скетч: модель получает просьбу и картинку одним сообщением автора", async () => {
  const { deps, calls } = scripted(mines, [planUse("t1", floodPlan)]);
  const r = await handle(ask({ image: sketch }), deps);
  assert.equal(r.status, 200);
  const first = calls[0].messages[0].content as { type: string; text?: string; mime?: string; data?: string }[];
  assert.equal(first[0].type, "text");
  assert.match(first[0].text!, /Создай персонажа по скетчу/);
  assert.match(first[0].text!, /рисунок/);
  assert.deepEqual(first[1], { type: "image", ...sketch });
});

test("скетч: формат OpenAI — картинка частью сообщения автора (data URL)", () => {
  const o = toOpenAI({
    system: "правила",
    tools: [],
    messages: [{ role: "user", content: [{ type: "text", text: "просьба" }, { type: "image", ...sketch }] }],
  }, "m");
  assert.deepEqual(o.messages[1], {
    role: "user",
    content: [
      { type: "text", text: "просьба" },
      { type: "image_url", image_url: { url: "data:image/jpeg;base64,AAAA" } },
    ],
  });
});

/// Какую модель спросили: подменённый fetch запоминает поле model.
function seenModels() {
  const seen: string[] = [];
  globalThis.fetch = (async (_url: string, init: RequestInit) => {
    seen.push(JSON.parse(String(init.body)).model);
    return new Response(JSON.stringify({ choices: [{ message: { role: "assistant", content: "ok" } }] }), { status: 200 });
  }) as typeof fetch;
  return seen;
}
const env = (keys: Record<string, string>) => (name: string) => keys[name];
const call = { system: "", tools: [], messages: [{ role: "user" as const, content: "x" }] };

test("скетч: с картинкой — только модель со зрением (qwen), без запасных без зрения", async () => {
  const seen = seenModels();
  const m = pickModel(undefined, env({ GROQ_API_KEY: "k", GEMINI_API_KEY: "k" }), true);
  if (typeof m === "string") throw new Error(m);
  await m(call);
  await m({ ...call, tier: 1 });
  assert.deepEqual(seen, ["qwen/qwen3.8-27b", "qwen/qwen3.8-27b"]);
});

test("скетч: модель без зрения или нет ключа — отказ словами", () => {
  assert.match(String(pickModel("groq:openai/gpt-oss-120b", env({ GROQ_API_KEY: "k" }), true)), /не видит картинок/);
  assert.match(String(pickModel(undefined, env({ GEMINI_API_KEY: "k" }), true)), /нет ключа модели с картинками/);
  assert.equal(typeof pickModel("groq:qwen/qwen3.8-27b", env({ GROQ_API_KEY: "k" }), true), "function");
});
