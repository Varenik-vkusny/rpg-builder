// Выбор модели: только бесплатные из списка, ключ — только из секретов.
import assert from "node:assert/strict";
import { test } from "node:test";

import { pickModel } from "./providers.ts";

const env = (keys: Record<string, string>) => (name: string) => keys[name];

test("провайдер: модель из списка и ключ есть — вызов готов", () => {
  assert.equal(typeof pickModel("mistral:mistral-large-latest", env({ MISTRAL_API_KEY: "k" })), "function");
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
