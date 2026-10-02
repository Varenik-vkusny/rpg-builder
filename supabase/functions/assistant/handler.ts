// Ассистент правок: просьба + область → план. В базу не пишет ничего.
// Модель и мир приходят зависимостями — тесты подставляют заранее заданную модель.
import type { AuthorQuestion, Plan } from "./plan.ts";
import { authorCheck, isServerQuestion, SERVER_QUESTIONS } from "./inner_places.ts";
import { outOfScope, TOOLS } from "./plan.ts";
import type { ScopeType, World } from "./world.ts";
import { key, objectsByKey, scopeOf } from "./world.ts";
import { systemPrompt, userPrompt } from "./prompt.ts";
import { checkSchema } from "./schema_check.ts";
import { toPlan } from "./ops.ts";
import { repairPlan } from "./repair.ts";

/// Не больше двух исправлений плана по ошибкам проверки (VISION.md, раздел 10).
export const MAX_FIXES = 2;
/// Ходов модели внутри одного запроса: каждый ход — план; повтор — только если план отклонён
/// (не по схеме, вне области). Бесплатный Flash — 20 запросов в день, поэтому 4.
export const MAX_TURNS = 4;
/// С этого хода (с нуля) модели остаётся один инструмент — propose_plan. Данные области уже в
/// подсказке (prompt.ts), читать нечего: 1 вызов на попытку. Так укладываемся в бесплатный
/// лимит Flash (5 в минуту, 20 в день), а Flash-Lite читала по кругу (живой прогон 25.09.2026).
export const FORCE_PLAN_FROM = 0;
/// Сколько раз модель может предложить план с операциями вне области, прежде чем
/// функция откажет (VISION.md, правило 5).
export const MAX_OUT_OF_SCOPE = 2;
/// Сколько вопросов ассистент может задать автору на одну просьбу; дальше — только план.
export const MAX_QUESTIONS = 2;
/// Весь ответ функции — не дольше 120 с: платформа обрывает функцию на 150 с (546 без объяснений),
/// 30 с — запас на чтение мира и ответ. Не уложились — 504 с тем, что модель успела сделать.
export const TOTAL_MS = 120_000;
/// Ответов не по схеме подряд, после которых берём запасную модель провайдера.
export const SCHEMA_FAILS_TO_FALLBACK = 2;

/// Картинка к просьбе — base64 не длиннее: предел Groq на картинку в base64 — 4 МБ.
export const MAX_IMAGE_CHARS = 4_000_000;
const IMAGE_MIMES = ["image/jpeg", "image/png", "image/webp"];

/// Фото скетча к просьбе (4.4): уходит модели со зрением частью сообщения автора.
export interface SketchImage {
  mime: string;
  data: string;
}

/// Ответ автора на вопрос ассистента.
export interface Answer {
  question: string;
  answer: string;
}

export interface AssistantRequest {
  project_id: string;
  scope: { type: ScopeType; slug: string };
  request: string;
  attempt: number;
  previous_plan: Plan | null;
  problems: string[];
  /// Ответы автора на прошлые вопросы ассистента по этой просьбе.
  answers: Answer[];
  /// Фото скетча; нет — null.
  image: SketchImage | null;
}

// Ход модели блоками text / tool_use (формат петли; Gemini переводит gemini.ts).
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
  /// Только этот инструмент на этом ходу (нет — любой).
  only?: string;
  /// Когда кончается время всего ответа (мс с 1970) — вызов модели не ждёт дольше.
  deadline?: number;
  /// Какая модель из списка провайдера: 0 — основная; после двух ответов не по схеме — следующая.
  tier?: number;
}

export interface Deps {
  loadWorld(projectId: string): Promise<World | null>;
  callModel(call: ModelCall): Promise<ModelResponse>;
  now?: () => number;
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
  const answers = r.answers ?? [];
  if (
    !Array.isArray(answers) ||
    answers.some((a) => typeof a?.question !== "string" || typeof a?.answer !== "string" || !a.answer.trim())
  ) {
    return "answers — список {question, answer}";
  }
  const fromServer = (answers as Answer[]).filter((a) => isServerQuestion(a.question)).length;
  if (answers.length - fromServer > MAX_QUESTIONS || fromServer > SERVER_QUESTIONS.length) {
    return `не больше ${MAX_QUESTIONS} вопросов автору`;
  }
  const image = (r.image ?? null) as SketchImage | null;
  if (image !== null) {
    if (!IMAGE_MIMES.includes(image?.mime) || typeof image.data !== "string" || !image.data) {
      return "картинка — {mime: jpeg|png|webp, data: base64}";
    }
    if (image.data.length > MAX_IMAGE_CHARS) return `картинка больше ${MAX_IMAGE_CHARS} символов base64`;
  }
  return {
    project_id: r.project_id,
    scope: { type: scope.type as ScopeType, slug: scope.slug },
    request: r.request.trim(),
    attempt: attempt as number,
    previous_plan: (r.previous_plan as Plan | null) ?? null,
    problems: problems as string[],
    answers: answers as Answer[],
    image: image && { mime: image.mime, data: image.data },
  };
}

const tool = (name: string) => TOOLS.find((t) => t.name === name)!;
const QUESTION_SCHEMA = tool("ask_author").input_schema;

/// Ответ модели «план отклонён»: ошибка на propose_plan, остальным вызовам — «не выполнено».
/// Каждому вызову — свой ответ: Gemini молча обрывает разговор, если ответов меньше, чем вызовов.
function rejectPlan(uses: ModelBlock[], proposed: ModelBlock, lines: string[]) {
  return {
    role: "user" as const,
    content: uses.map((u) => ({
      type: "tool_result",
      tool_use_id: u.id,
      is_error: true,
      content: u === proposed ? lines.join("\n") : "не выполнено: план отклонён",
    })),
  };
}

type Usage = { input_tokens: number; output_tokens: number };

/// Вопрос автору по схеме (2–4 варианта) — ответ телефону; иначе — строки отказа модели.
function questionReply(input: unknown, usage: Usage): Reply | string[] {
  const q = checkSchema(input, QUESTION_SCHEMA);
  const n = (q.value as AuthorQuestion | undefined)?.options?.length ?? 0;
  const errors = [...q.errors, ...(q.errors.length === 0 && (n < 2 || n > 4) ? [`вариантов ${n}, нужно 2–4`] : [])];
  if (errors.length === 0) return { status: 200, body: { question: q.value, usage } };
  return ["Вопрос не по схеме ask_author:", ...errors.slice(0, 20), "Задай вопрос заново строго по схеме."];
}

/// План по схеме и в области — ответ телефону. Иначе — строки отказа модели, запись для
/// трассировки и (если план вне области) что именно вне её.
/// Схему держит сервер: модель может прислать план не по форме. Модель пишет короткий формат,
/// телефон получает прежний (ops.ts).
function planReply(
  input: unknown,
  scope: Set<string>,
  worldKeys: Set<string>,
  usage: Usage,
): Reply | { lines: string[]; trace: string; outside: string[] | null } {
  const { plan, errors } = toPlan(input);
  if (!plan) {
    return {
      lines: ["План не по схеме propose_plan:", ...errors.slice(0, 20), "Отдай план заново строго по схеме."],
      trace: `план не по схеме (${errors[0]})`,
      outside: null,
    };
  }
  // Опечатки в slug и порядок операций сервер чинит сам — с пометкой для автора.
  const fixed = repairPlan(plan, scope, worldKeys);
  const bad = outOfScope(fixed, scope, worldKeys);
  if (bad.length === 0) return { status: 200, body: { plan: fixed, usage } };
  // Вне области: план отклонён. Модель узнаёт почему и может исправить.
  return {
    lines: ["План отклонён — операции вне области:", ...bad, "Предложи план заново только в границах области."],
    trace: `план вне области (${bad[0]})`,
    outside: bad,
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

/// Ответы на вызовы чтения — одним сообщением, каждому вызову свой.
function readReplies(uses: ModelBlock[], w: World, scope: Set<string>) {
  return {
    role: "user" as const,
    content: uses.map((u) => ({
      type: "tool_result",
      tool_use_id: u.id,
      content: JSON.stringify(readTool(u.name!, u.input as Record<string, unknown>, w, scope)),
    })),
  };
}

/// Первый вызов модели: правила мира, просьба, инструменты и срок всего ответа.
function firstCall(req: AssistantRequest, world: World, scope: Set<string>, mayAsk: boolean, deadline: number): ModelCall {
  return {
    system: systemPrompt(world, scope),
    tools: mayAsk ? [tool("ask_author"), tool("propose_plan")] : [tool("propose_plan")],
    // Скетч — частью сообщения автора: текст и картинка одним ходом.
    messages: [{
      role: "user",
      content: req.image
        ? [{ type: "text", text: userPrompt(req) }, { type: "image", ...req.image }]
        : userPrompt(req),
    }],
    deadline,
  };
}

/// Ответ не по схеме: после SCHEMA_FAILS_TO_FALLBACK подряд следующий ход — у запасной модели.
/// Возвращает новый счётчик подряд идущих провалов.
function onSchemaFail(call: ModelCall, fails: number, trace: string[]): number {
  if (fails < SCHEMA_FAILS_TO_FALLBACK) return fails;
  call.tier = (call.tier ?? 0) + 1;
  trace.push("дальше запасная модель");
  return 0;
}

export async function handle(body: unknown, deps: Deps): Promise<Reply> {
  const req = parseRequest(body);
  if (typeof req === "string") return fail(400, req);
  const world = await deps.loadWorld(req.project_id);
  if (!world) return fail(404, "мир не найден");
  const scope = scopeOf(world, req.scope.type, req.scope.slug);
  if (scope.size === 0) return fail(404, "объект области не найден");

  // Спросить автора можно только о самой просьбе (не в исправлении) и не больше MAX_QUESTIONS раз;
  // вопросы сервера (inner_places.ts) в этот счёт не входят.
  const modelAsked = req.answers.filter((a) => !isServerQuestion(a.question)).length;
  const mayAsk = req.attempt === 0 && modelAsked < MAX_QUESTIONS;
  const now = deps.now ?? Date.now;
  const call = firstCall(req, world, scope, mayAsk, now() + TOTAL_MS);
  const worldKeys = new Set(objectsByKey(world).keys());
  const usage = { input_tokens: 0, output_tokens: 0 };
  let outside = 0, schemaFails = 0;
  // Что модель делала по ходам — уходит в ответ, если плана так и не будет.
  const trace: string[] = [];
  for (let turn = 0; turn < MAX_TURNS; turn++) {
    if (now() >= call.deadline!) return fail(504, `модель не уложилась в ${TOTAL_MS / 1000} с: ${trace.join("; ")}`, { usage, trace });
    if (turn >= FORCE_PLAN_FROM && !mayAsk) call.only = "propose_plan";
    const res = await deps.callModel(call);
    usage.input_tokens += res.usage.input_tokens;
    usage.output_tokens += res.usage.output_tokens;
    if (res.stop_reason === "refusal") return fail(502, "модель отказалась", { usage });
    call.messages.push({ role: "assistant", content: res.content });

    const uses = res.content.filter((b) => b.type === "tool_use");
    const asked = mayAsk ? uses.find((b) => b.name === "ask_author") : undefined;
    if (asked) {
      const r = questionReply(asked.input, usage);
      if (!Array.isArray(r)) return r;
      trace.push(`вопрос не по схеме (${r[1]})`);
      schemaFails = onSchemaFail(call, schemaFails + 1, trace);
      call.messages.push(rejectPlan(uses, asked, r));
      continue;
    }
    const proposed = uses.find((b) => b.name === "propose_plan");
    if (proposed) {
      const r = planReply(proposed.input, scope, worldKeys, usage);
      if ("status" in r) {
        // Места внутри места и удаление жителя — с согласия автора (inner_places.ts).
        const root = req.scope.type === "location" ? world.locations.find((l) => l.slug === req.scope.slug) ?? null : null;
        const check = authorCheck(r.body.plan as Plan, world, scope, req.answers, req.attempt === 0, root, req.request);
        if (!check) return r;
        if ("ask" in check) return { status: 200, body: { question: check.ask, usage } };
        trace.push(check.reject[0]);
        call.messages.push(rejectPlan(uses, proposed, check.reject));
        continue;
      }
      trace.push(r.trace);
      if (!r.outside) schemaFails = onSchemaFail(call, schemaFails + 1, trace);
      if (r.outside && ++outside >= MAX_OUT_OF_SCOPE) {
        return fail(422, "операции вне области", { out_of_scope: r.outside, usage });
      }
      call.messages.push(rejectPlan(uses, proposed, r.lines));
      continue;
    }
    if (uses.length === 0) {
      trace.push(`без инструмента (${res.stop_reason ?? "?"})`);
      call.messages.push({ role: "user", content: "Отдай итог инструментом propose_plan." });
      continue;
    }
    trace.push(uses.map((u) => u.name).join("+"));
    call.messages.push(readReplies(uses, world, scope));
  }
  return fail(502, `модель не предложила план за ${MAX_TURNS} ходов: ${trace.join("; ")}`, { usage, trace });
}
