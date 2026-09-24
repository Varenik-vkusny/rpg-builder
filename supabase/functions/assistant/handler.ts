// Ассистент правок: просьба + область → план. В базу не пишет ничего.
// Модель и мир приходят зависимостями — тесты подставляют заранее заданную модель.
import type { Plan } from "./plan.ts";
import { TOOLS } from "./plan.ts";
import type { ScopeType, World } from "./world.ts";
import { key, objectsByKey, scopeOf } from "./world.ts";
import { systemPrompt, userPrompt } from "./prompt.ts";

/// Не больше двух исправлений плана по ошибкам проверки (VISION.md, раздел 10).
export const MAX_FIXES = 2;
/// Ходов модели внутри одного запроса: чтение объектов и сам план.
export const MAX_TURNS = 8;

export interface AssistantRequest {
  project_id: string;
  scope: { type: ScopeType; slug: string };
  request: string;
  attempt: number;
  previous_plan: Plan | null;
  problems: string[];
}

// Ответ модели — ровно те поля Messages API, что нужны петле.
export interface ModelBlock {
  type: string;
  id?: string;
  name?: string;
  input?: unknown;
  text?: string;
}
export interface ModelResponse {
  stop_reason: string | null;
  content: ModelBlock[];
  usage: { input_tokens: number; output_tokens: number };
}
export interface ModelCall {
  system: string;
  tools: typeof TOOLS;
  messages: { role: "user" | "assistant"; content: unknown }[];
}

export interface Deps {
  loadWorld(projectId: string): Promise<World | null>;
  callModel(call: ModelCall): Promise<ModelResponse>;
}

export interface Reply {
  status: number;
  body: Record<string, unknown>;
}

const fail = (status: number, error: string, extra: Record<string, unknown> = {}): Reply => ({
  status,
  body: { error, ...extra },
});

/// Разбор тела запроса; строка — что не так.
export function parseRequest(b: unknown): AssistantRequest | string {
  const r = b as Record<string, unknown> | null;
  if (!r || typeof r !== "object") return "тело запроса — объект";
  const scope = r.scope as Record<string, unknown> | undefined;
  if (typeof r.project_id !== "string") return "нет project_id";
  if (!scope || !["location", "quest", "character"].includes(scope.type as string)) {
    return "область: локация, квест или персонаж";
  }
  if (typeof scope.slug !== "string" || !scope.slug) return "нет slug области";
  if (typeof r.request !== "string" || !r.request.trim()) return "пустая просьба";
  if (r.request.length > 2000) return "просьба длиннее 2000 символов";
  const attempt = r.attempt ?? 0;
  if (!Number.isInteger(attempt) || (attempt as number) < 0) return "attempt — целое от 0";
  if ((attempt as number) > MAX_FIXES) return `не больше ${MAX_FIXES} исправлений`;
  const problems = r.problems ?? [];
  if (!Array.isArray(problems) || problems.some((p) => typeof p !== "string")) {
    return "problems — список строк";
  }
  if ((attempt as number) > 0 && !r.previous_plan) return "исправлению нужен предыдущий план";
  return {
    project_id: r.project_id,
    scope: { type: scope.type as ScopeType, slug: scope.slug },
    request: r.request.trim(),
    attempt: attempt as number,
    previous_plan: (r.previous_plan as Plan | null) ?? null,
    problems: problems as string[],
  };
}

/// Ответ инструмента чтения. Всё — только внутри области.
function readTool(name: string, input: Record<string, unknown>, w: World, scope: Set<string>): unknown {
  const all = objectsByKey(w);
  if (name === "find_in_scope") {
    const q = typeof input.query === "string" ? input.query.toLowerCase() : "";
    return [...scope]
      .map((k) => ({ k, o: all.get(k)! }))
      .filter(({ o }) => !input.type || o.type === input.type)
      .filter(({ o }) => !q || o.title.toLowerCase().includes(q))
      .map(({ k, o }) => ({ type: o.type, slug: k.split(":")[1], title: o.title }));
  }
  const k = key(String(input.type), String(input.slug));
  if (!scope.has(k)) return { error: `${k} вне области или не существует` };
  return all.get(k)!.data;
}

export async function handle(body: unknown, deps: Deps): Promise<Reply> {
  const req = parseRequest(body);
  if (typeof req === "string") return fail(400, req);
  const world = await deps.loadWorld(req.project_id);
  if (!world) return fail(404, "мир не найден");
  const scope = scopeOf(world, req.scope.type, req.scope.slug);
  if (scope.size === 0) return fail(404, "объект области не найден");

  const call: ModelCall = {
    system: systemPrompt(world, scope),
    tools: TOOLS,
    messages: [{ role: "user", content: userPrompt(req) }],
  };
  const usage = { input_tokens: 0, output_tokens: 0 };
  for (let turn = 0; turn < MAX_TURNS; turn++) {
    const res = await deps.callModel(call);
    usage.input_tokens += res.usage.input_tokens;
    usage.output_tokens += res.usage.output_tokens;
    if (res.stop_reason === "refusal") return fail(502, "модель отказалась", { usage });
    call.messages.push({ role: "assistant", content: res.content });

    const uses = res.content.filter((b) => b.type === "tool_use");
    const plan = uses.find((b) => b.name === "propose_plan");
    if (plan) return { status: 200, body: { plan: plan.input as Plan, usage } };
    if (uses.length === 0) {
      call.messages.push({ role: "user", content: "Отдай итог инструментом propose_plan." });
      continue;
    }
    call.messages.push({
      role: "user",
      content: uses.map((u) => ({
        type: "tool_result",
        tool_use_id: u.id,
        content: JSON.stringify(readTool(u.name!, u.input as Record<string, unknown>, world, scope)),
      })),
    });
  }
  return fail(502, "модель не предложила план", { usage });
}
