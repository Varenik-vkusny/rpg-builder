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

/// Какие объекты операция меняет и на какие ссылается — ключами области.
function touched(op: PlanOp): { changes: string[]; creates: string | null; refs: string[] } {
  const f = op.fields;
  const refs: string[] = [];
  if (f.location) refs.push(key("location", f.location));
  if (f.giver) refs.push(key("character", f.giver));
  // Цель без вида шага не проверить по области — такая ссылка не пропускается никогда.
  if (f.target) refs.push(f.step_kind ? key(stepTargetType(f.step_kind), f.target) : key("шаг-без-вида", f.target));
  if (op.type === "loot") {
    return { changes: [key("character", op.character ?? "")], creates: null, refs: [...refs, key("item", op.item ?? "")] };
  }
  if (op.type === "quest_step" || op.type === "quest_reward") {
    if (op.type === "quest_reward") refs.push(key("item", op.item ?? ""));
    return { changes: [key("quest", op.quest ?? "")], creates: null, refs };
  }
  const me = key(op.type, op.slug ?? "");
  return op.action === "create"
    ? { changes: [], creates: me, refs }
    : { changes: [me], creates: null, refs };
}

/// Операции вне области — человеческими строками. Пусто — план в границах.
/// Меняет, удаляет или ссылается на объект вне области — нельзя; созданное планом — можно.
/// [world] — все ключи мира: тогда причина точнее — объект не указан или его нет вовсе
/// (опечатка в slug), а не «вне области»; иначе модель повторяет ту же ошибку.
export function outOfScope(plan: Plan, scope: Set<string>, world?: Set<string>): string[] {
  const created = new Set(plan.ops.map(touched).map((t) => t.creates).filter((k): k is string => k !== null));
  const allowed = (k: string) => scope.has(k) || created.has(k);
  const out: string[] = [];
  plan.ops.forEach((op, i) => {
    const t = touched(op);
    for (const k of [...t.changes, ...t.refs]) {
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
