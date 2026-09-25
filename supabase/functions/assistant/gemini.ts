// Переходник: разговор петли ассистента (handler.ts) ↔ Gemini generateContent.
// Петля говорит блоками tool_use / tool_result; здесь они становятся functionCall /
// functionResponse. Ход модели уходит обратно в Gemini как есть (блок gemini_turn) —
// с подписями мыслей (thoughtSignature), иначе Gemini 3 теряет нить между ходами.
import type { ModelBlock, ModelCall, ModelResponse } from "./handler.ts";
import { postModel } from "./model_http.ts";

export { ModelError } from "./model_http.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

const LOCAL_ID = "local_";

/// Отказы по безопасности — для петли это «модель отказалась».
const REFUSAL = new Set(["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII", "RECITATION"]);

export function toGemini(call: ModelCall): Json {
  const names = new Map<string, string>(); // id вызова → имя инструмента
  const contents = call.messages.map((m) => {
    if (m.role === "assistant") {
      const blocks = m.content as ModelBlock[];
      for (const b of blocks) if (b.type === "tool_use") names.set(b.id!, b.name!);
      const turn = blocks.find((b) => b.type === "gemini_turn");
      return turn ? (turn.input as Json) : { role: "model", parts: blocks.map(blockToPart) };
    }
    if (typeof m.content === "string") return { role: "user", parts: [{ text: m.content }] };
    return {
      role: "user",
      parts: (m.content as Json[]).map((r) => ({
        functionResponse: {
          ...(String(r.tool_use_id).startsWith(LOCAL_ID) ? {} : { id: r.tool_use_id }),
          name: names.get(r.tool_use_id) ?? "unknown",
          response: r.is_error ? { error: r.content } : { result: r.content },
        },
      })),
    };
  });
  return {
    systemInstruction: { parts: [{ text: call.system }] },
    contents,
    tools: [{
      functionDeclarations: call.tools.map((t) => ({
        name: t.name,
        description: t.description,
        parametersJsonSchema: t.input_schema,
      })),
    }],
    // Каждый ход — вызов инструмента: чтение или итоговый план.
    toolConfig: {
      functionCallingConfig: { mode: "ANY", ...(call.only ? { allowedFunctionNames: [call.only] } : {}) },
    },
  };
}

function blockToPart(b: ModelBlock): Json {
  if (b.type === "tool_use") return { functionCall: { name: b.name, args: b.input } };
  return { text: b.text ?? "" };
}

export function fromGemini(res: Json): ModelResponse {
  const u = res.usageMetadata ?? {};
  const usage = {
    input_tokens: u.promptTokenCount ?? 0,
    output_tokens: (u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0),
  };
  const cand = res.candidates?.[0];
  if (res.promptFeedback?.blockReason || REFUSAL.has(cand?.finishReason)) {
    return { stop_reason: "refusal", content: [], usage };
  }
  const content: ModelBlock[] = [];
  // Ход целиком (с подписями мыслей и id вызовов) — чтобы вернуть его Gemini без потерь.
  const parts: Json[] = cand?.content?.parts ?? [];
  parts.forEach((p: Json, i: number) => {
    if (p.functionCall) {
      // Gemini 3 даёт id сам; нет — петле свой (LOCAL_ID), а Gemini id не отправляем.
      const fc = p.functionCall;
      content.push({ type: "tool_use", id: fc.id ?? `${LOCAL_ID}${i}`, name: fc.name, input: fc.args ?? {} });
    }
    if (typeof p.text === "string" && !p.thought) content.push({ type: "text", text: p.text });
  });
  content.push({ type: "gemini_turn", input: { role: "model", parts } });
  const stop = content.some((b) => b.type === "tool_use") ? "tool_use" : (cand?.finishReason ?? null);
  return { stop_reason: stop, content, usage };
}

/// Вызов Gemini по HTTP. Ключ — только из секрета функции (VISION.md, правило 9).
/// Повторы — общие (model_http.ts): перегружена (503) — запасная модель, 429 — пауза Gemini.
export function callGemini(
  apiKey: string,
  models: string[],
  call: ModelCall,
  wait = (ms: number) => new Promise((r) => setTimeout(r, ms)),
): Promise<ModelResponse> {
  return postModel({
    models,
    send: (model) =>
      fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
        body: JSON.stringify(toGemini(call)),
      }),
    retryAfterMs: (_r, body) => retryDelayMs(body),
    fallbackOn: [503],
    wait,
  }).then(fromGemini);
}

/// «retryDelay»: «12s» из подробностей ошибки 429 — в миллисекундах.
function retryDelayMs(body: Json): number | null {
  const d = (body?.error?.details ?? []).find((x: Json) => typeof x?.retryDelay === "string");
  const s = d ? parseFloat(d.retryDelay) : NaN;
  return Number.isFinite(s) ? s * 1000 : null;
}
