// Короткий формат плана для модели: у каждого вида операции — только свои поля, плоско,
// без пустых null. Слабая бесплатная модель путалась в общей схеме на ~25 полей (VISION.md, §10).
// Приложение видит прежний формат (PlanOp): перевод здесь, на сервере.
import type { Plan, PlanFields, PlanOp } from "./plan.ts";
import { checkSchema } from "./schema_check.ts";

export const FIELD_NAMES = [
  "title", "description", "level_min", "level_max", "parent", "kind", "rarity", "level",
  "damage", "defense", "price", "role", "hp", "attack", "location", "giver",
  "step_kind", "target", "amount", "chance",
] as const;

const INT_FIELDS = new Set([
  "level_min", "level_max", "level", "damage", "defense", "price", "hp", "attack", "amount",
]);

const ENUMS: Record<string, string[]> = {
  kind: ["weapon", "armor", "consumable", "quest", "misc"],
  rarity: ["common", "uncommon", "rare", "epic", "legendary"],
  role: ["npc", "merchant", "enemy"],
  step_kind: ["talk", "kill", "collect", "visit"],
};

const nullable = (type: string, extra: Record<string, unknown> = {}) => ({
  anyOf: [{ type, ...extra }, { type: "null" }],
});

/// Поле объекта: не указано или null — «не задаю / не меняю».
function fieldSchema(f: string) {
  if (ENUMS[f]) return nullable("string", { enum: ENUMS[f] });
  if (f === "chance") return nullable("number");
  return nullable(INT_FIELDS.has(f) ? "integer" : "string");
}

type OpType = PlanOp["type"];
type IdName = "slug" | "character" | "item" | "quest" | "position";

/// Вид операции: чем она указывает на объект и какие поля у неё есть.
const KINDS: Record<OpType, { about: string; ids: IdName[]; fields: (keyof PlanFields)[] }> = {
  location: {
    about: "Локация по slug; parent — slug места, внутри которого она лежит («» — верхний уровень)",
    ids: ["slug"],
    fields: ["title", "description", "level_min", "level_max", "parent"],
  },
  item: { about: "Предмет по slug", ids: ["slug"], fields: ["title", "kind", "rarity", "level", "damage", "defense", "price"] },
  character: {
    about: "Персонаж по slug; location — slug локации",
    ids: ["slug"],
    fields: ["title", "description", "role", "level", "hp", "attack", "location"],
  },
  quest: { about: "Квест по slug; giver — slug жителя", ids: ["slug"], fields: ["title", "description", "giver"] },
  loot: { about: "Добыча врага: character — slug врага, item — slug предмета", ids: ["character", "item"], fields: ["chance"] },
  quest_step: {
    about: "Шаг квеста: quest — slug квеста, position — номер с 1; target — slug цели",
    ids: ["quest", "position"],
    fields: ["step_kind", "target", "amount"],
  },
  quest_reward: { about: "Награда квеста: quest — slug квеста, item — slug предмета", ids: ["quest", "item"], fields: [] },
};

export const OP_TYPES = Object.keys(KINDS) as OpType[];

function kindSchema(type: OpType) {
  const k = KINDS[type];
  return {
    type: "object",
    description: k.about,
    properties: {
      action: { type: "string", enum: ["create", "update", "delete"] },
      type: { type: "string", enum: [type] },
      ...Object.fromEntries(k.ids.map((id) => [id, { type: id === "position" ? "integer" : "string" }])),
      ...Object.fromEntries(k.fields.map((f) => [f, fieldSchema(f)])),
    },
    required: ["action", "type", ...k.ids],
    additionalProperties: false,
  };
}

const KIND_SCHEMAS = Object.fromEntries(OP_TYPES.map((t) => [t, kindSchema(t)])) as Record<OpType, ReturnType<typeof kindSchema>>;

/// Схема ввода propose_plan — то, что видит модель.
export const PLAN_INPUT_SCHEMA = {
  type: "object",
  properties: {
    summary: { type: "string", description: "Одна фраза: что меняет план" },
    ops: { type: "array", items: { anyOf: OP_TYPES.map((t) => KIND_SCHEMAS[t]) } },
  },
  required: ["summary", "ops"],
  additionalProperties: false,
};

const emptyFields = (): PlanFields =>
  Object.fromEntries(FIELD_NAMES.map((f) => [f, null])) as unknown as PlanFields;

/// Короткий план модели → план приложения. Ошибки — по путям («ops[2].hp: …»), для модели.
/// Каждая операция проверяется схемой своего вида: ошибка говорит о её полях, а не обо всех видах сразу.
export function toPlan(input: unknown): { plan: Plan | null; errors: string[] } {
  const r = input as Record<string, unknown> | null;
  if (!r || typeof r !== "object" || Array.isArray(r)) return { plan: null, errors: ["план: нужен объект {summary, ops}"] };
  const errors: string[] = [];
  if (typeof r.summary !== "string") errors.push("summary: нужна строка");
  for (const k of Object.keys(r)) if (k !== "summary" && k !== "ops") errors.push(`${k}: лишнее поле`);
  if (!Array.isArray(r.ops)) return { plan: null, errors: [...errors, "ops: нужен список операций"] };
  const ops: PlanOp[] = [];
  r.ops.forEach((raw, i) => {
    const type = (raw as Record<string, unknown> | null)?.type as OpType;
    if (!KIND_SCHEMAS[type]) {
      errors.push(`ops[${i}].type: ${JSON.stringify(type)} не из ${OP_TYPES.join("|")}`);
      return;
    }
    const c = checkSchema(raw, KIND_SCHEMAS[type], `ops[${i}]`);
    if (c.errors.length > 0) return errors.push(...c.errors);
    const v = c.value as Record<string, unknown>;
    const fields = emptyFields();
    for (const f of KINDS[type].fields) (fields as unknown as Record<string, unknown>)[f] = v[f];
    const id = (n: IdName) => (KINDS[type].ids.includes(n) ? v[n] : null);
    ops.push({
      action: v.action as PlanOp["action"],
      type,
      slug: id("slug") as string | null,
      character: id("character") as string | null,
      item: id("item") as string | null,
      quest: id("quest") as string | null,
      position: id("position") as number | null,
      fields,
    });
  });
  if (errors.length > 0) return { plan: null, errors };
  return { plan: { summary: r.summary as string, ops }, errors };
}

/// План приложения → короткий формат модели (прошлый план в подсказке исправления).
export function toShort(plan: Plan): unknown {
  return {
    summary: plan.summary,
    ops: (plan.ops ?? []).map((op) => {
      const k = KINDS[op.type];
      if (!k) return op;
      const out: Record<string, unknown> = { action: op.action, type: op.type };
      for (const id of k.ids) out[id] = op[id];
      for (const f of k.fields) if (op.fields?.[f] != null) out[f] = op.fields[f];
      return out;
    }),
  };
}
