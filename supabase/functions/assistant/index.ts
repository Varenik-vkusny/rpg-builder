// Серверная функция Supabase «assistant»: телефон → сюда → Gemini → план обратно на телефон.
// Ключ API — только секрет функции GEMINI_API_KEY (VISION.md, правило 9).
// Мир читается с правами автора (его JWT): чужой мир RLS не отдаст.
import { createClient } from "npm:@supabase/supabase-js@2";

import { callGemini, ModelError } from "./gemini.ts";
import { handle } from "./handler.ts";
import { loadWorld } from "./load_world.ts";

// Модель — Gemini (VISION.md, раздел 10). Бесплатный уровень (замер 09.2026): Flash —
// 5 запросов в минуту и 20 в день, Flash-Lite — 15 и 500. Flash-Lite сцену не тянула
// (живой прогон 25.09.2026), поэтому Flash: данные области сразу в подсказке, 1 вызов на
// попытку, до 3 на сцену. Сменить без выкладки — секрет GEMINI_MODEL. Основная модель
// перегружена у Google (503) — запасная.
const MODELS = [Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash", "gemini-3.5-flash"];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json(500, { error: "у функции нет секрета GEMINI_API_KEY" });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });

  try {
    const reply = await handle(await req.json(), {
      loadWorld: (id) => loadWorld(db, id),
      callModel: (call) => callGemini(apiKey, MODELS, call),
    });
    return json(reply.status, reply.body);
  } catch (e) {
    if (e instanceof ModelError) return json(502, { error: `модель недоступна: ${e.status} ${e.message}` });
    return json(500, { error: String(e) });
  }
});
