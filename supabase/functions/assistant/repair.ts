// Сервер чинит план до проверки на копии — то, в чём бесплатная модель ошибается чаще всего
// и что чинится однозначно (VISION.md, §10). Каждая починка видна автору пометкой у операции.
// 1) Опечатка в slug: чинится ТОЛЬКО если близкий slug один — среди объектов области и созданных
//    этим планом, — и рядом нет похожего объекта вне области. Иначе остаётся ошибкой модели.
// 2) Порядок: сначала создать, потом переписать ссылки, потом удалить.
import type { Plan, PlanOp } from "./plan.ts";
import { key, stepTargetType } from "./world.ts";

const OBJECTS = ["location", "item", "character", "quest"];

/// Расстояние правки (Левенштейн).
function distance(a: string, b: string): number {
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const cur = [i];
    for (let j = 1; j <= b.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Близко — похоже на опечатку: 1 правка у коротких slug, 2 — до 10 букв, 3 — длиннее.
export function isTypo(a: string, b: string): boolean {
  const n = Math.max(a.length, b.length);
  return distance(a, b) <= (n <= 5 ? 1 : n <= 10 ? 2 : 3);
}

/// Где в операции стоит ссылка на объект: вид объекта, значение, как заменить.
function slots(op: PlanOp): { type: string; get: () => string | null; set: (v: string) => void }[] {
  const out: { type: string; get: () => string | null; set: (v: string) => void }[] = [];
  const f = op.fields;
  if (OBJECTS.includes(op.type) && op.action !== "create") out.push({ type: op.type, get: () => op.slug, set: (v) => (op.slug = v) });
  if (op.type === "loot") out.push({ type: "character", get: () => op.character, set: (v) => (op.character = v) });
  if (op.type === "loot" || op.type === "quest_reward") out.push({ type: "item", get: () => op.item, set: (v) => (op.item = v) });
  if (op.type === "quest_step" || op.type === "quest_reward") out.push({ type: "quest", get: () => op.quest, set: (v) => (op.quest = v) });
  if (f.location) out.push({ type: "location", get: () => f.location, set: (v) => (f.location = v) });
  if (f.giver) out.push({ type: "character", get: () => f.giver, set: (v) => (f.giver = v) });
  if (f.target && f.step_kind) out.push({ type: stepTargetType(f.step_kind), get: () => f.target, set: (v) => (f.target = v) });
  return out;
}

const note = (op: PlanOp, text: string) => (op.repairs = [...(op.repairs ?? []), text]);

/// Опечатки в slug — там, где починка однозначна.
function fixTypos(ops: PlanOp[], scope: Set<string>, world: Set<string>) {
  const created = new Set(ops.filter((o) => o.action === "create" && OBJECTS.includes(o.type)).map((o) => key(o.type, o.slug ?? "")));
  const known = [...scope, ...created];
  for (const op of ops) {
    for (const s of slots(op)) {
      const v = s.get();
      if (!v) continue;
      const k = key(s.type, v);
      if (scope.has(k) || created.has(k) || world.has(k)) continue;
      const near = (keys: Iterable<string>) =>
        [...new Set(keys)].filter((x) => x.startsWith(`${s.type}:`) && isTypo(v, x.slice(s.type.length + 1)));
      const inside = near(known);
      const outside = near([...world].filter((x) => !scope.has(x)));
      if (inside.length !== 1 || outside.length > 0) continue;
      const to = inside[0].slice(s.type.length + 1);
      s.set(to);
      note(op, `опечатка в slug: ${v} → ${to}`);
    }
  }
}

/// Ключи объектов, на которые операция ссылается или которые меняет (кроме создаваемого).
const refs = (op: PlanOp) => slots(op).map((s) => key(s.type, s.get() ?? ""));
const own = (op: PlanOp) => key(op.type, op.slug ?? "");
const isObj = (op: PlanOp) => OBJECTS.includes(op.type);

/// Сначала создать, потом переписать ссылки, потом удалить. Создание двигаем вперёд, только если
/// на объект ссылаются раньше; удаление объекта — в конец, если после него есть правки.
/// Остальные операции — в порядке модели. Объект и создаётся, и удаляется — не трогаем.
function fixOrder(ops: PlanOp[]): PlanOp[] {
  const made = new Set(ops.filter((o) => isObj(o) && o.action === "create").map(own));
  if (ops.some((o) => isObj(o) && o.action === "delete" && made.has(own(o)))) return ops;
  const early = ops.filter((o, i) =>
    isObj(o) && o.action === "create" && ops.slice(0, i).some((x) => refs(x).includes(own(o)))
  );
  // Удаление — всегда после правок: шаг квеста, переписанный с удаляемого врага на нового,
  // в самой операции удаляемого не упоминает (живой прогон 26.09, gpt-oss-120b).
  const late = ops.filter((o, i) =>
    isObj(o) && o.action === "delete" && ops.slice(i + 1).some((x) => !(isObj(x) && x.action === "delete"))
  );
  const rank = (o: PlanOp) => OBJECTS.indexOf(o.type);
  early.sort((a, b) => rank(a) - rank(b));
  late.sort((a, b) => rank(b) - rank(a));
  const out = [...early, ...ops.filter((o) => !early.includes(o) && !late.includes(o)), ...late];
  for (const o of [...early, ...late]) {
    note(o, `порядок: была операция ${ops.indexOf(o) + 1}, стала ${out.indexOf(o) + 1}`);
  }
  return out;
}

/// План после починки; пометки — в repairs у операций (автор видит их в «было → стало»).
export function repairPlan(plan: Plan, scope: Set<string>, world: Set<string>): Plan {
  const ops: PlanOp[] = plan.ops.map((o) => ({ ...o, fields: { ...o.fields } }));
  fixTypos(ops, scope, world);
  return { ...plan, ops: fixOrder(ops) };
}
