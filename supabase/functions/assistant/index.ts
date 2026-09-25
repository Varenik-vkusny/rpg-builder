// Серверная функция Supabase «assistant»: телефон → сюда → модель (Groq или Gemini) → план на телефон.
// Ключи API — только секреты функции GROQ_API_KEY / GEMINI_API_KEY (VISION.md, правило 9).
// Мир читается с правами автора (его JWT): чужой мир RLS не отдаст.
import { createClient } from "npm:@supabase/supabase-js@2";

import { callGemini } from "./gemini.ts";
import { ModelError } from "./model_http.ts";
import { callOpenAI } from "./openai_compat.ts";
import { handle } from "./handler.ts";
import type { ModelCall } from "./handler.ts";
import { loadWorld } from "./load_world.ts";

// Модель. Владелец не платит (25.09.2026): бесплатные провайдеры без карты.
// Есть секрет GROQ_API_KEY — Groq (1000 запросов в день, отвечает за секунды), иначе Gemini.
// Модель меняется секретом GROQ_MODEL / GEMINI_MODEL, без выкладки; вторая в списке — запасная.
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const GROQ_MODELS = [Deno.env.get("GROQ_MODEL") ?? "openai/gpt-oss-120b", "llama-3.3-70b-versatile"];
// Gemini бесплатно: Flash — 5 в минуту и 20 в день; перегружена (503) — запасная.
const GEMINI_MODELS = [Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash", "gemini-3.5-flash"];

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
  const groqKey = Deno.env.get("GROQ_API_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!groqKey && !geminiKey) return json(500, { error: "у функции нет секрета GROQ_API_KEY или GEMINI_API_KEY" });
  const callModel = groqKey
    ? (call: ModelCall) => callOpenAI(GROQ_URL, groqKey, GROQ_MODELS, call)
    : (call: ModelCall) => callGemini(geminiKey!, GEMINI_MODELS, call);

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });

  try {
    const reply = await handle(await req.json(), {
      loadWorld: (id) => loadWorld(db, id),
      callModel,
    });
    return json(reply.status, reply.body);
  } catch (e) {
    if (e instanceof ModelError) return json(502, { error: `модель недоступна: ${e.status} ${e.message}` });
    return json(500, { error: String(e) });
  }
});
