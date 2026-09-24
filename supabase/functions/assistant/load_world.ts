// Мир из базы с правами автора → вид для ассистента: id заменены на slug.
import type { World } from "./world.ts";

type Row = Record<string, unknown>;
// Клиент supabase-js; тип упрощён, чтобы файл не тянул npm-пакет в тесты.
// deno-lint-ignore no-explicit-any
type Db = any;

async function rows(db: Db, table: string, columns: string, projectId: string): Promise<Row[]> {
  const { data, error } = await db.from(table).select(columns).eq("project_id", projectId).order("created_at");
  if (error) throw new Error(`${table}: ${error.message}`);
  return data as Row[];
}

/// null — мира нет или он чужой (RLS его не отдаёт).
export async function loadWorld(db: Db, projectId: string): Promise<World | null> {
  const { data: p, error } = await db.from("projects").select().eq("id", projectId).maybeSingle();
  if (error) throw new Error(`projects: ${error.message}`);
  if (!p) return null;
  const [locations, items, characters, quests] = await Promise.all([
    rows(db, "locations", "*", projectId),
    rows(db, "items", "*", projectId),
    rows(db, "characters", "*, loot(item_id, chance)", projectId),
    rows(db, "quests", "*, quest_steps(position, kind, character_id, item_id, location_id, amount), quest_rewards(item_id)", projectId),
  ]);
  const slug = new Map<unknown, string>();
  for (const r of [...locations, ...items, ...characters]) slug.set(r.id, r.slug as string);
  const s = (id: unknown) => (id == null ? null : slug.get(id) ?? String(id));

  return {
    title: p.title, setting: p.setting, tone: p.tone, level_min: p.level_min, level_max: p.level_max,
    locations: locations.map((l) => ({
      slug: l.slug as string, title: l.title as string, description: l.description as string,
      level_min: l.level_min as number, level_max: l.level_max as number,
    })),
    items: items.map((i) => ({
      slug: i.slug as string, title: i.title as string, kind: i.kind as string, rarity: i.rarity as string,
      level: i.level as number, damage: i.damage as number | null, defense: i.defense as number | null,
      price: i.price as number,
    })),
    characters: characters.map((c) => ({
      slug: c.slug as string, title: c.title as string, description: c.description as string,
      role: c.role as string, level: c.level as number, hp: c.hp as number, attack: c.attack as number,
      location: s(c.location_id),
      loot: (c.loot as Row[]).map((l) => ({ item: s(l.item_id)!, chance: Number(l.chance) })),
    })),
    quests: quests.map((q) => ({
      slug: q.slug as string, title: q.title as string, description: q.description as string,
      giver: s(q.giver_id),
      steps: [...(q.quest_steps as Row[])]
        .sort((a, b) => (a.position as number) - (b.position as number))
        .map((st) => ({
          kind: st.kind as string,
          target: s(st.character_id ?? st.item_id ?? st.location_id)!,
          amount: st.amount as number | null,
        })),
      rewards: (q.quest_rewards as Row[]).map((r) => s(r.item_id)!),
    })),
  };
}
