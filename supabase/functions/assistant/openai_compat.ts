// Переходник: разговор петли ассистента (handler.ts) ↔ API в формате OpenAI
// (Chat Completions). Так говорят Groq, GitHub Models, Cerebras, OpenRouter — бесплатные
// провайдеры без карты (владелец, 25.09.2026). Провайдер — адрес и ключ, код один.
import type { ModelBlock, ModelCall, ModelResponse } from "./handler.ts";
import { postModel } from "./model_http.ts";
import { relaxNullable } from "./schema_check.ts";

// deno-lint-ignore no-explicit-any
type Json = any;

export function toOpenAI(call: ModelCall, model: string): Json {
  const messages: Json[] = [{ role: "system", content: call.system }];
  for (const m of call.messages) {
    if (m.role === "assistant") {
      const blocks = m.content as ModelBlock[];
      // Ход модели уходит обратно как был (с id вызовов).
      const turn = blocks.find((b) => b.type === "openai_turn");
      messages.push(turn ? turn.input : {
        role: "assistant",
        content: blocks.filter((b) => b.type === "text").map((b) => b.text).join("\n") || null,
        tool_calls: blocks.filter((b) => b.type === "tool_use").map((b) => ({
          id: b.id,
          type: "function",
          function: { name: b.name, arguments: JSON.stringify(b.input ?? {}) },
        })),
      });
    } else if (typeof m.content === "string") {
      messages.push({ role: "user", content: m.content });
    } else if ((m.content as Json[])[0]?.type === "text") {
      // Просьба со скетчем: текст и картинка (data URL) одним сообщением автора.
      messages.push({
        role: "user",
        content: (m.content as Json[]).map((b) =>
          b.type === "image" ? { type: "image_url", image_url: { url: `data:${b.mime};base64,${b.data}` } } : b
        ),
      });
    } else {
      // Ответы инструментов — каждый своим сообщением, с id вызова.
      for (const r of m.content as Json[]) {
        messages.push({
          role: "tool",
          tool_call_id: r.tool_use_id,
          content: r.is_error ? `ОШИБКА: ${r.content}` : String(r.content),
        });
      }
    }
  }
  return {
    model,
    messages,
    // Разрешён один инструмент — модель видит только его: иначе Groq отклоняет вызов чужого.
    tools: call.tools.filter((t) => !call.only || t.name === call.only).map((t) => ({
      type: "function",
      // Пустые поля — необязательные: Groq иначе сам отклоняет вызов, где модель их опустила.
      function: { name: t.name, description: t.description, parameters: relaxNullable(t.input_schema) },
    })),
    tool_choice: call.only ? { type: "function", function: { name: call.only } } : "required",
  };
}

export function fromOpenAI(res: Json): ModelResponse {
  const usage = {
    input_tokens: res.usage?.prompt_tokens ?? 0,
    output_tokens: res.usage?.completion_tokens ?? 0,
  };
  const choice = res.choices?.[0];
  if (choice?.finish_reason === "content_filter") return { stop_reason: "refusal", content: [], usage };
  const msg = choice?.message ?? { role: "assistant", content: null };
  const content: ModelBlock[] = [];
  if (typeof msg.content === "string" && msg.content) content.push({ type: "text", text: msg.content });
  for (const tc of msg.tool_calls ?? []) {
    let input: unknown;
    try {
      input = JSON.parse(tc.function?.arguments ?? "{}");
    } catch {
      // Не JSON — отдаём строкой: проверка схемы скажет модели, что пришло не то.
      input = tc.function?.arguments;
    }
    content.push({ type: "tool_use", id: tc.id, name: tc.function?.name, input });
  }
  content.push({
    type: "openai_turn",
    input: { role: "assistant", content: msg.content ?? null, ...(msg.tool_calls ? { tool_calls: msg.tool_calls } : {}) },
  });
  const stop = content.some((b) => b.type === "tool_use") ? "tool_use" : (choice?.finish_reason ?? null);
  return { stop_reason: stop, content, usage };
}

/// Вызов по HTTP. Повторы — общие (model_http.ts): сбой или таймаут — повтор, потом следующая
/// модель; нет модели (404) — сразу следующая; 429 — ждём, сколько просит провайдер (retry-after).
export function callOpenAI(
  url: string,
  apiKey: string,
  models: string[],
  call: ModelCall,
  wait = (ms: number) => new Promise((r) => setTimeout(r, ms)),
): Promise<ModelResponse> {
  return postModel({
    models,
    send: (model, signal) =>
      fetch(url, {
        method: "POST",
        signal,
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
        body: JSON.stringify(toOpenAI(call, model)),
      }),
    retryAfterMs: (r) => {
      const s = parseFloat(r.headers.get("retry-after") ?? "");
      return Number.isFinite(s) ? s * 1000 : null;
    },
    fallbackOn: [404],
    wait,
    deadline: call.deadline,
  }).then(fromOpenAI);
}
