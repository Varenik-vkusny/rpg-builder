// План изменений: формат, строгие схемы инструментов, проверка границ области.
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

const FIELD_NAMES = [
  "title", "description", "level_min", "level_max", "kind", "rarity", "level",
  "damage", "defense", "price", "role", "hp", "attack", "location", "giver",
  "step_kind", "target", "amount", "chance",
] as const;

const INT_FIELDS = new Set([
  "level_min", "level_max", "level", "damage", "defense", "price", "hp", "attack", "amount",
]);

const fieldsSchema = {
  type: "object",
  description:
    "Поля объекта. null — поле не задаётся (при изменении — не меняется). " +
    "location, giver, target — slug объекта.",
  properties: Object.fromEntries(
    FIELD_NAMES.map((f) => {
      if (f === "kind") return [f, nullable("string", { enum: ["weapon", "armor", "consumable", "quest", "misc"] })];
      if (f === "rarity") return [f, nullable("string", { enum: ["common", "uncommon", "rare", "epic", "legendary"] })];
      if (f === "role") return [f, nullable("string", { enum: ["npc", "merchant", "enemy"] })];
      if (f === "step_kind") return [f, nullable("string", { enum: ["talk", "kill", "collect", "visit"] })];
      if (f === "chance") return [f, nullable("number")];
      return [f, nullable(INT_FIELDS.has(f) ? "integer" : "string")];
    }),
  ),
  required: [...FIELD_NAMES],
  additionalProperties: false,
};

const opSchema = {
  type: "object",
  properties: {
    action: { type: "string", enum: ["create", "update", "delete"] },
    type: {
      type: "string",
      enum: ["location", "item", "character", "quest", "loot", "quest_step", "quest_reward"],
    },
    slug: { ...nullable("string"), description: "slug объекта (location, item, character, quest)" },
    character: { ...nullable("string"), description: "slug врага (loot)" },
    item: { ...nullable("string"), description: "slug предмета (loot, quest_reward)" },
    quest: { ...nullable("string"), description: "slug квеста (quest_step, quest_reward)" },
    position: { ...nullable("integer"), description: "номер шага с 1 (quest_step)" },
    fields: fieldsSchema,
  },
  required: ["action", "type", "slug", "character", "item", "quest", "position", "fields"],
  additionalProperties: false,
};

/// Инструменты модели: чтение, вопрос автору и «предложить план». Записи нет (VISION.md, правило 1).
/// Схему плана сервер проверяет сам (schema_check.ts): Gemini не держит её строго.
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
    input_schema: {
      type: "object",
      properties: {
        summary: { type: "string", description: "Одна фраза: что меняет план" },
        ops: { type: "array", items: opSchema },
      },
      required: ["summary", "ops"],
      additionalProperties: false,
    },
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
