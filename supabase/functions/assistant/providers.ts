// Провайдеры моделей: какой адрес и какой секрет. Все бесплатные, без карты (владелец, 25.09.2026).
// Формат OpenAI у всех, кроме Gemini, — переходник один (openai_compat.ts).
// Запрос может выбрать модель полем `model` — только из этого списка (сравнение живыми прогонами).
import type { ModelCall, ModelResponse } from "./handler.ts";
import { callGemini } from "./gemini.ts";
import { callOpenAI } from "./openai_compat.ts";

interface Provider {
  /// Секрет функции с ключом API.
  secret: string;
  /// Адрес Chat Completions; нет — это Gemini.
  url?: string;
  models: string[];
}

export const PROVIDERS: Record<string, Provider> = {
  groq: {
    secret: "GROQ_API_KEY",
    url: "https://api.groq.com/openai/v1/chat/completions",
    // Первая — модель по умолчанию (владелец, 26.09): gpt-oss-120b после А2 прошла сцену 3.9 5/5.
    models: ["openai/gpt-oss-120b", "qwen/qwen3.8-27b", "openai/gpt-oss-20b"],
  },
  mistral: {
    secret: "MISTRAL_API_KEY",
    url: "https://api.mistral.ai/v1/chat/completions",
    // Бесплатный тариф (страница Limits, 26.09): large-2512 — 250 000 токенов/мин; medium и small —
    // по 20 000 (прогон сцены ≈ 20 000). «mistral-large-latest» тарифом закрыт (403).
    models: ["mistral-large-2512", "mistral-medium-latest", "mistral-small-2603"],
  },
  zai: {
    secret: "ZAI_API_KEY",
    url: "https://api.z.ai/api/paas/v4/chat/completions",
    models: ["glm-4.7-flash", "glm-4.5-flash"],
  },
  gemini: {
    secret: "GEMINI_API_KEY",
    models: ["gemini-3.8-flash", "gemini-3.5-flash"],
  },
};

/// Модель по умолчанию, когда запрос её не выбрал: первый провайдер, у которого есть ключ.
/// Порядок — от сильного к слабому по сравнению 25.09.2026 (scripts/compare_models.sh).
export const DEFAULT_ORDER = ["groq", "gemini"];

export type CallModel = (call: ModelCall) => Promise<ModelResponse>;

/// «провайдер:модель» из запроса (или по умолчанию) → вызов модели; остальные модели провайдера —
/// запасные (сбой или таймаут — model_http.ts; ответы не по схеме — call.tier в handler.ts).
/// Строка — что не так: чужая модель или у провайдера нет ключа.
export function pickModel(requested: unknown, env: (name: string) => string | undefined): CallModel | string {
  const bind = (name: string, models: string[]): CallModel | string => {
    const p = PROVIDERS[name];
    const key = env(p.secret);
    if (!key) return `у функции нет секрета ${p.secret}`;
    // Запасная модель (call.tier) — следующая по списку; дальше конца списка не уходим.
    const from = (call: ModelCall) => models.slice(Math.min(call.tier ?? 0, models.length - 1));
    return p.url
      ? (call) => callOpenAI(p.url!, key, from(call), call)
      : (call) => callGemini(key, from(call), call);
  };
  if (typeof requested === "string" && requested) {
    const [name, ...rest] = requested.split(":");
    const model = rest.join(":");
    if (!PROVIDERS[name]?.models.includes(model)) return `модель ${requested} не из списка бесплатных`;
    // Выбранная — первой, запасные — остальные модели провайдера по порядку.
    return bind(name, [model, ...PROVIDERS[name].models.filter((m) => m !== model)]);
  }
  for (const name of DEFAULT_ORDER) {
    if (env(PROVIDERS[name].secret)) return bind(name, PROVIDERS[name].models);
  }
  return `у функции нет ключа ни одного провайдера (${DEFAULT_ORDER.map((n) => PROVIDERS[n].secret).join(", ")})`;
}
