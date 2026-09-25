// Переходник петли ассистента ↔ Gemini generateContent (без сети).
import assert from "node:assert/strict";
import { test } from "node:test";

import { fromGemini, toGemini } from "./gemini.ts";
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
  assert.deepEqual(g.tools[0].functionDeclarations.map((f: { name: string }) => f.name), ["find_in_scope", "read_object", "propose_plan"]);
  assert.equal(g.tools[0].functionDeclarations[2].parametersJsonSchema, TOOLS[2].input_schema);
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
