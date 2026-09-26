// Общий вызов модели по HTTP для всех провайдеров (gemini.ts, openai_compat.ts): одна политика
// повторов, чтобы провайдеры не разъехались в поведении.
// [models] — по порядку: модель недоступна ([fallbackOn]) — берём следующую.
// Упёрлись в лимит в минуту (429) — ждём, сколько просит провайдер (от 2 до 30 с), и пробуем ту же
// модель снова, до RATE_WAITS раз: бесплатный Groq — 8000 токенов в минуту, а одна просьба ~3–4 тыс.

/// Сколько раз ждать лимит в минуту за один вызов модели.
export const RATE_WAITS = 3;

// deno-lint-ignore no-explicit-any
type Json = any;

export class ModelError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export interface ModelHttp {
  models: string[];
  send(model: string): Promise<Response>;
  /// Сколько ждать после 429, мс; null — провайдер не сказал.
  retryAfterMs(r: Response, body: Json): number | null;
  fallbackOn: number[];
  wait: (ms: number) => Promise<unknown>;
}

/// Текст ошибки провайдера: у OpenAI, Groq, Gemini — error.message, у Mistral — message или detail.
function errorText(body: Json): string | null {
  const t = body?.error?.message ?? body?.message ?? body?.detail;
  return t == null ? null : typeof t === "string" ? t : JSON.stringify(t);
}

/// Тело успешного ответа или ModelError.
export async function postModel(h: ModelHttp): Promise<Json> {
  let waits = 0;
  for (let i = 0; i < h.models.length;) {
    const r = await h.send(h.models[i]);
    const body = await r.json().catch(() => ({}));
    if (r.status === 429 && waits < RATE_WAITS) {
      waits++;
      await h.wait(Math.min(Math.max(h.retryAfterMs(r, body) ?? 20_000, 2_000), 30_000));
      continue;
    }
    if (h.fallbackOn.includes(r.status) && i + 1 < h.models.length) {
      i++;
      continue;
    }
    if (!r.ok) throw new ModelError(r.status, errorText(body) ?? r.statusText);
    return body;
  }
  throw new ModelError(500, "нет моделей");
}
