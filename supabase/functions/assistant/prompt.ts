// Тексты для модели: правила мира и просьба автора.
import type { AssistantRequest } from "./handler.ts";
import type { World } from "./world.ts";
import { key, objectsByKey } from "./world.ts";
import { toShort } from "./ops.ts";

export function systemPrompt(w: World, scope: Set<string>): string {
  const all = objectsByKey(w);
  const list = [...scope]
    .map((k) => `- ${k} — «${all.get(k)!.title}»`)
    .join("\n");
  // Все поля объектов области сразу: модели не нужно читать их по одному (1 вызов на попытку).
  const data = [...scope].map((k) => `${k}: ${JSON.stringify(all.get(k)!.data)}`).join("\n");
  const nested = nestedHint(w, scope);
  return `Ты — ассистент правок мира RPG. Автор описывает изменение одной фразой, ты составляешь план изменений.
В базу ты не пишешь: план увидит автор, код проверит его на копии мира, и только автор решит, применять ли.

Мир «${w.title}». Сеттинг: ${w.setting || "—"}. Тон: ${w.tone || "—"}. Уровни мира: ${w.level_min}–${w.level_max}.

Область правки — только эти объекты (вид:slug):
${list}
Менять, удалять и упоминать можно только их и объекты, которые план сам создаёт. Остальной мир тебе не виден.
Все поля и связи объектов области (ссылки — по slug):
${data}${nested}
Итог отдай одним вызовом propose_plan.
Просьба спорит с правилами мира (потолки, уровни) или её можно понять по-разному — не исправляй
молча и не угадывай: если доступен ask_author, спроси автора (что просил, почему так нельзя, 2–4 варианта,
первым — тот, что советуешь). Один вопрос — одна развилка; вопрос и варианты — по-русски, словами автора,
без slug и названий полей. Просьба ясна и не спорит с правилами — сразу план.

Операции плана:
- location, item, character, quest: create / update / delete по slug. Новый slug — латиница, цифры и «_» (ashen_drowned), не совпадает с существующими.
- loot (добыча врага): character + item, поле chance (0 < шанс ≤ 100). update меняет шанс, delete убирает.
- quest_step: quest + position (с 1). create — только в конец (position = число шагов + 1); delete сдвигает следующие шаги; поля step_kind, target (slug), amount. С target всегда указывай и step_kind.
- quest_reward: quest + item, create / delete.
У каждой операции только поля своего вида; поле не указано — «не задаю / не меняю». role и kind задаются только при создании.
Удаление врага само убирает его добычу, удаление квеста — его шаги и награды: отдельные операции для них не нужны и будут ошибкой.
Операции выполняются по порядку: объект, на который что-то ссылается, удаляй после того, как убрал эти ссылки.

Правила мира:
- Локация: title, description, level_min ≤ level_max; parent — slug места, внутри которого она лежит («» — на верхний уровень). Места вложены не глубже 3 уровней; уровни вложенного — в пределах уровней родителя. Место с вложенными не удаляется.
- «Место» в просьбе — это место и вложенные в него: «затопи копи» меняет и штольни внутри копей.
- Предмет: kind weapon|armor|consumable|quest|misc, rarity common|uncommon|rare|epic|legendary, level ≥ 1, price ≥ 0. Урон (damage) только у оружия, защита (defense) только у брони.
- Персонаж: role npc (житель) | merchant | enemy; level ≥ 1, hp ≥ 1, attack ≥ 0; location — slug локации. Добыча только у врага.
- Квест: giver — житель (npc); шаги talk (персонаж), kill N (только враг), collect N (предмет), visit (локация); у квеста хотя бы один шаг.
- Потолок урона оружия: 4 + уровень × 2 × множитель редкости (1.0 / 1.2 / 1.5 / 1.9 / 2.4).
- Потолок атаки врага: 4 + уровень × 2. Уровень врага не выше верхнего уровня его локации.
- Каждый предмет должен выпадать из врага или выдаваться наградой.
Затрагивай всё связанное: если врага переселили, проверь квесты, где его надо убить, и его добычу.`;
}

/// Места внутри мест области — по имени: без этого модель меняла только верхнее место (02.10).
function nestedHint(w: World, scope: Set<string>): string {
  const inScope = (slug: string) => scope.has(key("location", slug));
  const inner = w.locations
    .filter((l) => inScope(l.slug))
    .map((l) => ({ l, kids: w.locations.filter((c) => c.parent === l.slug && inScope(c.slug)) }))
    .filter(({ kids }) => kids.length > 0)
    .map(({ l, kids }) => `Внутри «${l.title}»: ${kids.map((c) => `«${c.title}» (location:${c.slug})`).join(", ")}.`);
  if (inner.length === 0) return "";
  return `
${inner.join("\n")}
Просьба про место относится и к местам внутри него: каждое вложенное место, которого она касается, меняй своей операцией update с новым description — изменить одно верхнее место мало.`;
}

export function userPrompt(req: AssistantRequest): string {
  const sketch = req.image
    ? "\nК просьбе приложен рисунок автора (скетч): облик, имя, роль и описание бери с него, числа — по правилам мира."
    : "";
  // Просьба про место — его описание первой операцией (решение владельца 02.10).
  const first = req.scope.type === "location"
    ? `\nПросьба про место location:${req.scope.slug}: первой операцией плана измени его description, потом — места внутри и жителей.`
    : "";
  const ask = `Область: ${req.scope.type}:${req.scope.slug}.\nПросьба автора: ${req.request}${sketch}${first}`;
  const answered = req.answers.length === 0 ? "" : `
Ответы автора на твои вопросы — следуй им:
${req.answers.map((a) => `- Вопрос: ${a.question}\n  Ответ: ${a.answer}`).join("\n")}`;
  if (req.attempt === 0) return ask + answered;
  return `${ask}${answered}

Твой прошлый план проверка на копии мира не пропустила. Исправь его и отдай целиком заново.
Прошлый план:
${JSON.stringify(req.previous_plan ? toShort(req.previous_plan) : null)}
Проблемы:
${req.problems.map((p) => `- ${p}`).join("\n")}`;
}
