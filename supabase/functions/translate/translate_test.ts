// Прибор «перевод справочника» (5д): просьба проверяется, ответ модели — тоже (столько же строк);
// Groq не используется (на нём меряется защита); сбой первого переводчика — второй.
import assert from "node:assert/strict";
import { test } from "node:test";

import { readAnswer, readRequest, translate, TRANSLATORS } from "./translate.ts";

const answer = (t: unknown) => ({ choices: [{ message: { content: JSON.stringify({ t }) } }] });
const env = (keys: Record<string, string>) => (name: string) => keys[name];

test("перевод: просьба — непустые строки до 80 знаков, язык ru или en", () => {
  assert.deepEqual(readRequest({ texts: ["Skeleton"], to: "ru" }), { texts: ["Skeleton"], to: "ru" });
  assert.match(String(readRequest({ texts: ["Skeleton"], to: "de" })), /ru или en/);
  assert.match(String(readRequest({ texts: [], to: "ru" })), /непустой/);
  assert.match(String(readRequest({ texts: [" "], to: "ru" })), /от 1 до 80/);
  assert.match(String(readRequest({ texts: Array(41).fill("a"), to: "ru" })), /не больше 40/);
});

test("перевод: ответ модели — столько же строк, иначе не принят", () => {
  assert.deepEqual(readAnswer(answer(["Скелет", " Охряная слизь "]), 2), ["Скелет", "Охряная слизь"]);
  assert.equal(readAnswer(answer(["Скелет"]), 2), null);
  assert.equal(readAnswer(answer(["Скелет", ""]), 2), null);
  assert.equal(readAnswer({ choices: [{ message: { content: "Скелет" } }] }, 1), null);
  // Обёртка ```json — частая у моделей; снимаем.
  const fenced = { choices: [{ message: { content: '```json\n{"t":["Кирка"]}\n```' } }] };
  assert.deepEqual(readAnswer(fenced, 1), ["Кирка"]);
});

test("перевод: Groq не переводчик — его лимит у защиты", () => {
  assert.ok(TRANSLATORS.length > 0);
  assert.ok(TRANSLATORS.every((p) => p.secret !== "GROQ_API_KEY" && !p.url.includes("groq")));
});

test("перевод: первый с ключом ответил криво — второй; ключей нет — ошибка словами", async () => {
  const asked: string[] = [];
  const out = await translate(["Skeleton"], "ru", env({ MISTRAL_API_KEY: "m", GEMINI_API_KEY: "g" }), (url, key, body) => {
    asked.push(`${key}:${body.model}`);
    return Promise.resolve(key === "m" ? answer([]) : answer(["Скелет"]));
  });
  assert.deepEqual(out, ["Скелет"]);
  assert.equal(asked.length, 2);
  // Без ключа Mistral — сразу второй.
  const only = await translate(["кирка"], "en", env({ GEMINI_API_KEY: "g" }), () => Promise.resolve(answer(["pick"])));
  assert.deepEqual(only, ["pick"]);
  assert.match(String(await translate(["a"], "ru", env({}), () => Promise.reject(new Error("x")))), /нет ключа/);
  const failed = await translate(["a"], "ru", env({ MISTRAL_API_KEY: "m" }), () => Promise.reject(new Error("ответ 503")));
  assert.match(String(failed), /503/);
});
