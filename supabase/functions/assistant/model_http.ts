// Общий вызов модели по HTTP для всех провайдеров (gemini.ts, openai_compat.ts): одна политика
// повторов, чтобы провайдеры не разъехались в поведении.
// [models] — по порядку: модель недоступна ([fallbackOn]) — берём следующую; сбой (RETRY_ON) или
// таймаут — один повтор, потом следующая; суточный лимит (429 с долгой паузой) — следующая.
// Упёрлись в лимит в минуту (429) — ждём, сколько просит провайдер (от 2 до 30 с), и пробуем ту же
// модель снова, до RATE_WAITS раз: бесплатный Groq — 8000 токенов в минуту, а одна просьба ~3–4 тыс.

/// Сколько раз ждать лимит в минуту за один вызов модели.
export const RATE_WAITS = 3;
/// Один вызов модели ждём не дольше: дольше — таймаут, повтор, потом запасная модель.
export const CALL_TIMEOUT_MS = 60_000;
/// Пауза 429 длиннее — это суточный лимит (Groq: «try again in 12m»), ждать нечего: запасная модель.
export const MAX_RATE_WAIT_MS = 30_000;
/// Сбой модели, который лечится повтором: кривой вызов инструмента (Groq отдаёт 400),
/// перегрузка и сбои провайдера. Один повтор на той же модели, потом — следующая в списке.
const RETRY_ON = new Set([400, 500, 502, 503, 504]);

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
  send(model: string, signal: AbortSignal): Promise<Response>;
  /// Сколько ждать после 429, мс; null — провайдер не сказал.
  retryAfterMs(r: Response, body: Json): number | null;
  fallbackOn: number[];
  wait: (ms: number) => Promise<unknown>;
  /// Когда кончается время всего ответа (мс с 1970); позже — ModelError 504. Нет — без лимита.
  deadline?: number;
  now?: () => number;
}

const isTimeout = (e: unknown) => ["TimeoutError", "AbortError"].includes((e as Error)?.name);

/// Текст ошибки провайдера: у OpenAI, Groq, Gemini — error.message, у Mistral — message или detail.
function errorText(body: Json): string | null {
  const t = body?.error?.message ?? body?.message ?? body?.detail;
  return t == null ? null : typeof t === "string" ? t : JSON.stringify(t);
}

/// Тело успешного ответа или ModelError (последняя ошибка, если не ответила ни одна модель).
export async function postModel(h: ModelHttp): Promise<Json> {
  const now = h.now ?? Date.now;
  let waits = 0;
  let retried = false;
  let last = null as ModelError | null;
  // Следующая попытка: повтор на той же модели (один раз) или следующая модель.
  let i = 0;
  const next = (err: ModelError, retry: boolean) => {
    last = err;
    if (retry && !retried) retried = true;
    else [i, retried] = [i + 1, false];
  };
  while (i < h.models.length) {
    const left = (h.deadline ?? Infinity) - now();
    if (left <= 0) throw new ModelError(504, `модель не ответила вовремя${last ? ` (${last.status} ${last.message})` : ""}`);
    const limit = Math.min(CALL_TIMEOUT_MS, left);
    let r: Response;
    try {
      r = await h.send(h.models[i], AbortSignal.timeout(limit));
    } catch (e) {
      if (!isTimeout(e)) throw e;
      next(new ModelError(504, `${h.models[i]}: нет ответа за ${Math.round(limit / 1000)} с`), true);
      continue;
    }
    const body = await r.json().catch(() => ({}));
    const err = () => new ModelError(r.status, errorText(body) ?? r.statusText);
    if (r.status === 429) {
      const pause = Math.max(h.retryAfterMs(r, body) ?? 20_000, 2_000);
      if (pause <= MAX_RATE_WAIT_MS && waits < RATE_WAITS && pause < left) {
        waits++;
        await h.wait(pause);
        continue;
      }
      next(err(), false);
      continue;
    }
    if (RETRY_ON.has(r.status)) {
      next(err(), true);
      continue;
    }
    if (h.fallbackOn.includes(r.status)) {
      next(err(), false);
      continue;
    }
    if (!r.ok) throw err();
    return body;
  }
  throw last ?? new ModelError(500, "нет моделей");
}
