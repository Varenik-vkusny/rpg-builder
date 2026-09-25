// Общий вызов модели по HTTP для всех провайдеров (gemini.ts, openai_compat.ts): одна политика
// повторов, чтобы провайдеры не разъехались в поведении.
// [models] — по порядку: модель недоступна ([fallbackOn]) — берём следующую.
// Упёрлись в лимит в минуту (429) — ждём, сколько просит провайдер (не больше 30 с), и пробуем
// ту же модель ещё один раз: бесплатные уровни режут по минутам.

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

/// Тело успешного ответа или ModelError.
export async function postModel(h: ModelHttp): Promise<Json> {
  let waited = false;
  for (let i = 0; i < h.models.length;) {
    const r = await h.send(h.models[i]);
    const body = await r.json().catch(() => ({}));
    if (r.status === 429 && !waited) {
      waited = true;
      await h.wait(Math.min(h.retryAfterMs(r, body) ?? 20_000, 30_000));
      continue;
    }
    if (h.fallbackOn.includes(r.status) && i + 1 < h.models.length) {
      i++;
      continue;
    }
    if (!r.ok) throw new ModelError(r.status, body?.error?.message ?? r.statusText);
    return body;
  }
  throw new ModelError(500, "нет моделей");
}
