// Серверная функция Supabase «translate»: телефон → сюда → модель-переводчик → строки на телефон.
// Вызывает только вошедший автор (проверка JWT на входе функции). Мир не читает и не пишет.
import { readRequest, translate } from "./translate.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

/// Один вызов не дольше 20 с: автор ждёт находки.
async function send(url: string, key: string, body: unknown) {
  const r = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(20_000),
  });
  if (!r.ok) throw new Error(`ответ ${r.status}`);
  return await r.json();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const asked = readRequest(await req.json().catch(() => null));
  if (typeof asked === "string") return json(400, { error: asked });
  const out = await translate(asked.texts, asked.to, (n) => Deno.env.get(n), send);
  return typeof out === "string" ? json(502, { error: out }) : json(200, { texts: out });
});
