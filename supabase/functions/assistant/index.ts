// Серверная функция Supabase «assistant»: телефон → сюда → Claude → план обратно на телефон.
// Ключ API — только секрет функции ANTHROPIC_API_KEY (VISION.md, правило 9).
// Мир читается с правами автора (его JWT): чужой мир RLS не отдаст.
import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

import { handle } from "./handler.ts";
import { loadWorld } from "./load_world.ts";

// Модель сверена скиллом claude-api 24.09.2026: актуальная по умолчанию — Claude Opus 5.
const MODEL = "claude-opus-5";

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
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json(500, { error: "у функции нет секрета ANTHROPIC_API_KEY" });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const anthropic = new Anthropic({ apiKey });

  try {
    const reply = await handle(await req.json(), {
      loadWorld: (id) => loadWorld(db, id),
      callModel: (call) =>
        // deno-lint-ignore no-explicit-any
        (anthropic.beta.messages.create as any)({
          model: MODEL,
          max_tokens: 16000,
          thinking: { type: "adaptive" },
          output_config: { effort: "medium" },
          // При отказе модели запрос повторяет рекомендованная запасная модель.
          betas: ["server-side-fallback-2026-07-01"],
          fallbacks: "default",
          ...call,
        }),
    });
    return json(reply.status, reply.body);
  } catch (e) {
    if (e instanceof Anthropic.APIError) {
      return json(502, { error: `модель недоступна: ${e.status} ${e.message}` });
    }
    return json(500, { error: String(e) });
  }
});
