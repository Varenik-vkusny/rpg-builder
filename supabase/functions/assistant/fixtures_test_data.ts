// «Пепельные копи» из приёмки и подменённая модель с заранее заданными ответами.
import type { Deps, ModelCall, ModelResponse } from "./handler.ts";
import type { Plan, PlanFields, PlanOp } from "./plan.ts";
import type { World } from "./world.ts";
import { toShort } from "./ops.ts";

export const mines: World = {
  title: "Пепельные копи",
  setting: "шахтёрский посёлок",
  tone: "мрачный",
  level_min: 1,
  level_max: 10,
  locations: [
    { slug: "shtolnya_3", title: "Штольня №3", description: "обвалившаяся выработка", level_min: 2, level_max: 4, parent: null },
    { slug: "rynok", title: "Рынок", description: "", level_min: 1, level_max: 3, parent: null },
  ],
  items: [
    { slug: "klyuch", title: "Ключ от лебёдки", kind: "quest", rarity: "common", level: 2, damage: null, defense: null, price: 0 },
    { slug: "kirka", title: "Кирка", kind: "weapon", rarity: "rare", level: 3, damage: 6, defense: null, price: 40 },
    { slug: "yabloko", title: "Яблоко", kind: "consumable", rarity: "common", level: 1, damage: null, defense: null, price: 1 },
  ],
  characters: [
    { slug: "brigadir", title: "Бригадир Эрден", description: "", role: "npc", level: 1, hp: 10, attack: 0, location: null, loot: [] },
    { slug: "slizen", title: "Пепельный слизень", description: "", role: "enemy", level: 2, hp: 12, attack: 5, location: "shtolnya_3", loot: [{ item: "klyuch", chance: 35 }] },
    { slug: "torgovka", title: "Торговка", description: "", role: "merchant", level: 1, hp: 10, attack: 0, location: "rynok", loot: [] },
  ],
  quests: [
    {
      slug: "obval",
      title: "Обвал в третьей штольне",
      description: "",
      giver: "brigadir",
      steps: [
        { kind: "talk", target: "brigadir", amount: null },
        { kind: "kill", target: "slizen", amount: 4 },
        { kind: "collect", target: "klyuch", amount: 1 },
      ],
      rewards: ["kirka"],
    },
  ],
  events: [],
};

const NO_FIELDS: PlanFields = {
  title: null, description: null, level_min: null, level_max: null, parent: null, kind: null,
  rarity: null, level: null, damage: null, defense: null, price: null, role: null,
  hp: null, attack: null, location: null, giver: null, step_kind: null, target: null,
  amount: null, chance: null,
};

export function op(o: Partial<Omit<PlanOp, "fields">> & { fields?: Partial<PlanFields> }): PlanOp {
  return {
    action: "update", type: "location", slug: null, character: null, item: null,
    quest: null, position: null, ...o, fields: { ...NO_FIELDS, ...o.fields },
  };
}

/// План из сцены «штольня затоплена» — с атакой 14 при потолке 10 (ур. 3).
export const floodPlan: Plan = {
  summary: "Штольня №3 затоплена: слизни ушли, появились утопленники",
  ops: [
    op({ type: "location", slug: "shtolnya_3", fields: { description: "затоплена по пояс" } }),
    op({ action: "create", type: "character", slug: "utoplennik", fields: { title: "Утопленник", role: "enemy", level: 3, hp: 30, attack: 14, location: "shtolnya_3" } }),
    op({ action: "delete", type: "loot", character: "slizen", item: "klyuch" }),
    op({ action: "create", type: "loot", character: "utoplennik", item: "klyuch", fields: { chance: 35 } }),
    op({ type: "quest_step", quest: "obval", position: 2, fields: { step_kind: "kill", target: "utoplennik", amount: 3 } }),
  ],
};

export const toolUse = (id: string, name: string, input: unknown): ModelResponse => ({
  stop_reason: "tool_use",
  content: [{ type: "tool_use", id, name, input }],
  usage: { input_tokens: 100, output_tokens: 20 },
});

/// Модель предлагает план — коротким форматом, как настоящая (ops.ts).
export const planUse = (id: string, plan: Plan): ModelResponse => toolUse(id, "propose_plan", toShort(plan));

/// Подменённая модель: отвечает по списку и запоминает, что ей прислали.
export function scripted(world: World | null, answers: ModelResponse[]) {
  const calls: ModelCall[] = [];
  const deps: Deps = {
    loadWorld: async () => world,
    callModel: async (c) => {
      calls.push(structuredClone(c));
      const next = answers.shift();
      if (!next) throw new Error("модель спросили больше, чем задано ответов");
      return next;
    },
  };
  return { deps, calls };
}
