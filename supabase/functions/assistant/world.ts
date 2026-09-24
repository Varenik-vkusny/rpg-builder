// Мир глазами ассистента: объекты по slug, связи — тоже по slug.
// Чистый TypeScript без Deno и сети: те же файлы гоняет `node --test`.

export type ObjectType = "location" | "item" | "character" | "quest";
export type ScopeType = "location" | "quest" | "character";

export interface WorldLocation {
  slug: string;
  title: string;
  description: string;
  level_min: number;
  level_max: number;
}

export interface WorldItem {
  slug: string;
  title: string;
  kind: string;
  rarity: string;
  level: number;
  damage: number | null;
  defense: number | null;
  price: number;
}

export interface WorldCharacter {
  slug: string;
  title: string;
  description: string;
  role: string;
  level: number;
  hp: number;
  attack: number;
  location: string | null;
  loot: { item: string; chance: number }[];
}

export interface WorldQuest {
  slug: string;
  title: string;
  description: string;
  giver: string | null;
  steps: { kind: string; target: string; amount: number | null }[];
  rewards: string[];
}

export interface World {
  title: string;
  setting: string;
  tone: string;
  level_min: number;
  level_max: number;
  locations: WorldLocation[];
  items: WorldItem[];
  characters: WorldCharacter[];
  quests: WorldQuest[];
}

/// Ключ объекта в области: `character:ash_slime`.
export const key = (type: string, slug: string) => `${type}:${slug}`;

/// Вид цели шага квеста: поговорить и убить — персонаж, собрать — предмет, прийти — локация.
export function stepTargetType(kind: string): ObjectType {
  if (kind === "collect") return "item";
  if (kind === "visit") return "location";
  return "character";
}

/// Все связи мира как пары ключей (без направления).
function edges(w: World): [string, string][] {
  const out: [string, string][] = [];
  for (const c of w.characters) {
    const me = key("character", c.slug);
    if (c.location) out.push([me, key("location", c.location)]);
    for (const l of c.loot) out.push([me, key("item", l.item)]);
  }
  for (const q of w.quests) {
    const me = key("quest", q.slug);
    if (q.giver) out.push([me, key("character", q.giver)]);
    for (const s of q.steps) {
      out.push([me, key(stepTargetType(s.kind), s.target)]);
    }
    for (const r of q.rewards) out.push([me, key("item", r)]);
  }
  return out;
}

/// Все объекты мира по ключу.
export function objectsByKey(w: World): Map<string, { type: ObjectType; title: string; data: unknown }> {
  const m = new Map<string, { type: ObjectType; title: string; data: unknown }>();
  for (const x of w.locations) m.set(key("location", x.slug), { type: "location", title: x.title, data: x });
  for (const x of w.items) m.set(key("item", x.slug), { type: "item", title: x.title, data: x });
  for (const x of w.characters) m.set(key("character", x.slug), { type: "character", title: x.title, data: x });
  for (const x of w.quests) m.set(key("quest", x.slug), { type: "quest", title: x.title, data: x });
  return m;
}

/// Сколько связей от корня области до объекта включаем.
export const SCOPE_DEPTH = 2;

/// Область: выбранный объект и всё, что связано с ним не дальше двух связей.
/// Корня нет в мире — область пустая.
export function scopeOf(w: World, type: ScopeType, slug: string): Set<string> {
  const root = key(type, slug);
  if (!objectsByKey(w).has(root)) return new Set();
  const near = new Map<string, string[]>();
  for (const [a, b] of edges(w)) {
    near.set(a, [...(near.get(a) ?? []), b]);
    near.set(b, [...(near.get(b) ?? []), a]);
  }
  const seen = new Set([root]);
  let frontier = [root];
  for (let d = 0; d < SCOPE_DEPTH; d++) {
    const next: string[] = [];
    for (const k of frontier) {
      for (const n of near.get(k) ?? []) {
        if (!seen.has(n)) {
          seen.add(n);
          next.push(n);
        }
      }
    }
    frontier = next;
  }
  return seen;
}
