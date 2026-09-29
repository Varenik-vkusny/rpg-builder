// Серверная функция Supabase «assistant»: телефон → сюда → модель → план на телефон.
// Ключи API — только секреты функции (VISION.md, правило 9); какие — providers.ts.
// Мир читается с правами автора (его JWT): чужой мир RLS не отдаст.
import { createClient } from "npm:@supabase/supabase-js@2";

import { ModelError } from "./model_http.ts";
import { handle } from "./handler.ts";
import { loadWorld } from "./load_world.ts";
import { pickModel } from "./providers.ts";

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
  const body = await req.json().catch(() => null);
  // Просьба со скетчем — только модели, которые видят картинки.
  const callModel = pickModel(body?.model, (name) => Deno.env.get(name), Boolean(body?.image));
  if (typeof callModel === "string") return json(500, { error: callModel });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });

  try {
    const reply = await handle(body, {
      loadWorld: (id) => loadWorld(db, id),
      callModel,
    });
    return json(reply.status, reply.body);
  } catch (e) {
    if (e instanceof ModelError) return json(502, { error: `модель недоступна: ${e.status} ${e.message}` });
    return json(500, { error: String(e) });
  }
});
