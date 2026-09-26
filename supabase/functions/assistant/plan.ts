// План изменений: формат приложения, схемы инструментов, проверка границ области.
// Модель пишет план коротким форматом (ops.ts), сервер переводит его в этот.
import { PLAN_INPUT_SCHEMA } from "./ops.ts";
import { key, stepTargetType } from "./world.ts";

export interface PlanFields {
  title: string | null;
  description: string | null;
  level_min: number | null;
  level_max: number | null;
  kind: string | null;
  rarity: string | null;
  level: number | null;
  damage: number | null;
  defense: number | null;
  price: number | null;
  role: string | null;
  hp: number | null;
  attack: number | null;
  location: string | null;
  giver: string | null;
  step_kind: string | null;
  target: string | null;
  amount: number | null;
  chance: number | null;
}

export interface PlanOp {
  action: "create" | "update" | "delete";
  type: "location" | "item" | "character" | "quest" | "loot" | "quest_step" | "quest_reward";
  slug: string | null;
  character: string | null;
  item: string | null;
  quest: string | null;
  position: number | null;
  fields: PlanFields;
  /// Что сервер поправил в операции (repair.ts) — автор видит пометкой в «было → стало».
  repairs?: string[];
}

export interface Plan {
  summary: string;
  ops: PlanOp[];
}

const nullable = (type: string, extra: Record<string, unknown> = {}) => ({
  anyOf: [{ type, ...extra }, { type: "null" }],
});

/// Инструменты модели: чтение, вопрос автору и «предложить план». Записи нет (VISION.md, правило 1).
/// Схему плана сервер проверяет сам (ops.ts → schema_check.ts): бесплатные модели не держат её строго.
export const TOOLS = [
  {
    name: "find_in_scope",
    description: "Ищет объекты области по части названия и/или виду. Возвращает вид, slug и название.",
    input_schema: {
      type: "object",
      properties: {
        query: nullable("string"),
        type: nullable("string", { enum: ["location", "item", "character", "quest"] }),
      },
      required: ["query", "type"],
      additionalProperties: false,
    },
  },
  {
    name: "read_object",
    description: "Возвращает все поля объекта области и его связи (по slug).",
    input_schema: {
      type: "object",
      properties: {
        type: { type: "string", enum: ["location", "item", "character", "quest"] },
        slug: { type: "string" },
      },
      required: ["type", "slug"],
      additionalProperties: false,
    },
  },
  {
    name: "ask_author",
    description:
      "Спрашивает автора, когда просьба спорит с правилами мира или её можно понять по-разному. " +
      "Не исправляй просьбу молча — спроси. Автор увидит вопрос и варианты и сможет вписать свой.",
    input_schema: {
      type: "object",
      properties: {
        question: { type: "string", description: "Коротко: что просил автор и почему так нельзя или неясно" },
        options: {
          type: "array",
          description: "2–4 варианта, первый — тот, что советуешь",
          items: {
            type: "object",
            properties: {
              label: { type: "string", description: "Что сделать, 2–6 слов" },
              description: { type: "string", description: "Чем это обернётся" },
            },
            required: ["label", "description"],
            additionalProperties: false,
          },
        },
      },
      required: ["question", "options"],
      additionalProperties: false,
    },
  },
  {
    name: "propose_plan",
    description:
      "Отдаёт итоговый план автору на проверку. План ничего не записывает: автор увидит «было → стало» и решит сам.",
    input_schema: PLAN_INPUT_SCHEMA,
  },
];

export const OBJECTS = ["location", "item", "character", "quest"];

/// Ссылка операции на объект: вид объекта, значение, как заменить (repair.ts чинит опечатки).
export interface RefSlot {
  type: string;
  get: () => string | null;
  set: (v: string) => void;
}

/// Где в операции ссылки на объекты — одно место для области (outOfScope) и починки (repair.ts).
/// Сюда входит и сам изменяемый или удаляемый объект; создаваемый — нет.
export function refSlots(op: PlanOp): RefSlot[] {
  const out: RefSlot[] = [];
  const f = op.fields;
  if (OBJECTS.includes(op.type) && op.action !== "create") out.push({ type: op.type, get: () => op.slug, set: (v) => (op.slug = v) });
  if (op.type === "loot") out.push({ type: "character", get: () => op.character, set: (v) => (op.character = v) });
  if (op.type === "loot" || op.type === "quest_reward") out.push({ type: "item", get: () => op.item, set: (v) => (op.item = v) });
  if (op.type === "quest_step" || op.type === "quest_reward") out.push({ type: "quest", get: () => op.quest, set: (v) => (op.quest = v) });
  if (f.location) out.push({ type: "location", get: () => f.location, set: (v) => (f.location = v) });
  if (f.giver) out.push({ type: "character", get: () => f.giver, set: (v) => (f.giver = v) });
  // Цель без вида шага не проверить по области — такая ссылка не пропускается никогда.
  if (f.target) {
    const type = f.step_kind ? stepTargetType(f.step_kind) : "шаг-без-вида";
    out.push({ type, get: () => f.target, set: (v) => (f.target = v) });
  }
  return out;
}

/// Ключи объектов, которые операция меняет или на которые ссылается (кроме создаваемого).
export const refKeys = (op: PlanOp) => refSlots(op).map((s) => key(s.type, s.get() ?? ""));

/// Ключ объекта, который операция создаёт; null — не создаёт.
export const createdKey = (op: PlanOp) =>
  op.action === "create" && OBJECTS.includes(op.type) ? key(op.type, op.slug ?? "") : null;

/// Операции вне области — человеческими строками. Пусто — план в границах.
/// Меняет, удаляет или ссылается на объект вне области — нельзя; созданное планом — можно.
/// [world] — все ключи мира: тогда причина точнее — объект не указан или его нет вовсе
/// (опечатка в slug), а не «вне области»; иначе модель повторяет ту же ошибку.
export function outOfScope(plan: Plan, scope: Set<string>, world?: Set<string>): string[] {
  const created = new Set(plan.ops.map(createdKey).filter((k): k is string => k !== null));
  const allowed = (k: string) => scope.has(k) || created.has(k);
  const out: string[] = [];
  plan.ops.forEach((op, i) => {
    for (const k of refKeys(op)) {
      if (allowed(k)) continue;
      const at = `операция ${i + 1} (${op.action} ${op.type})`;
      const [type, slug] = k.split(":");
      if (!slug) out.push(`${at}: не указан slug (${type})`);
      else if (world && !world.has(k)) out.push(`${at}: ${k} нет в мире, и план его не создаёт — проверь написание slug`);
      else out.push(`${at}: ${k} вне области`);
    }
  });
  return out;
}

/// Вопрос ассистента автору: просьба спорит с правилами мира или неоднозначна.
export interface AuthorQuestion {
  question: string;
  options: { label: string; description: string }[];
}
