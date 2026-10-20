// Перевод названий справочника Open5e (5д): «кирка» → «pick» для поиска, «Skeleton» → «Скелет»
// для автора. Отдельная функция и не та модель, на которой меряется защита (VISION.md, 09.10):
// лимит Groq сцены «штольня» не тратится, функция ассистента не трогается.
// Ключи — только секреты функции (правило 9). Ответ модели проверяется: столько же строк и по порядку.

// deno-lint-ignore no-explicit-any
type Json = any;

/// Провайдеры по порядку; у кого нет ключа — пропускаем. Groq нет нарочно: на нём меряется защита.
export const TRANSLATORS = [
  {
    secret: "MISTRAL_API_KEY",
    url: "https://api.mistral.ai/v1/chat/completions",
    model: "mistral-small-2603",
  },
  {
    secret: "GEMINI_API_KEY",
    url: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
    model: "gemini-3.5-flash",
  },
];

/// Больше за раз не переводим: страница находок Open5e — 20 строк, предметы — две страницы.
export const MAX_TEXTS = 40;
export const MAX_LEN = 80;

export type Lang = "ru" | "en";

/// Что просили перевести, или строка — что не так с просьбой.
export function readRequest(body: Json): { texts: string[]; to: Lang } | string {
  const texts = body?.texts;
  const to = body?.to;
  if (to !== "ru" && to !== "en") return "to — ru или en";
  if (!Array.isArray(texts) || texts.length === 0) return "texts — непустой список строк";
  if (texts.length > MAX_TEXTS) return `не больше ${MAX_TEXTS} строк за раз`;
  if (texts.some((t) => typeof t !== "string" || !t.trim() || t.length > MAX_LEN)) {
    return `каждая строка — от 1 до ${MAX_LEN} знаков`;
  }
  return { texts, to };
}

/// Тело запроса Chat Completions: модель отвечает JSON {"t": [...]} в том же порядке.
export function buildCall(model: string, texts: string[], to: Lang): Json {
  const task = to === "ru"
    ? "Переведи названия существ и предметов D&D 5e на русский так, как их назвали бы в русском " +
      "издании. Имя собственное — транслитом. Начинай с заглавной буквы."
    : "Translate these Russian words into the English D&D 5e name an author would search for in " +
      "the SRD (one or two words, singular, lowercase).";
  return {
    model,
    temperature: 0,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: `${task} Ответ — только JSON {"t": [...]}: столько же строк, тот же порядок.`,
      },
      { role: "user", content: JSON.stringify(texts) },
    ],
  };
}

/// Переводы из ответа модели или null, если ответ не тот: строк не столько же, пустые, не JSON.
export function readAnswer(res: Json, count: number): string[] | null {
  const text = res?.choices?.[0]?.message?.content;
  if (typeof text !== "string") return null;
  let t: unknown;
  try {
    t = JSON.parse(text.replace(/^```(json)?\s*|\s*```$/g, ""))?.t;
  } catch {
    return null;
  }
  if (!Array.isArray(t) || t.length !== count) return null;
  if (t.some((s) => typeof s !== "string" || !s.trim() || s.length > MAX_LEN * 2)) return null;
  return t.map((s: string) => s.trim());
}

export type Send = (url: string, key: string, body: Json) => Promise<Json>;

/// Перевод: первый провайдер с ключом; сбой или кривой ответ — следующий. Никто — строка ошибки.
export async function translate(
  texts: string[],
  to: Lang,
  env: (name: string) => string | undefined,
  send: Send,
): Promise<string[] | string> {
  const fails: string[] = [];
  for (const p of TRANSLATORS) {
    const key = env(p.secret);
    if (!key) continue;
    try {
      const out = readAnswer(await send(p.url, key, buildCall(p.model, texts, to)), texts.length);
      if (out) return out;
      fails.push(`${p.model}: ответ не по форме`);
    } catch (e) {
      fails.push(`${p.model}: ${(e as Error).message}`);
    }
  }
  return fails.length ? `перевод не удался — ${fails.join("; ")}` : "у функции нет ключа переводчика";
}
