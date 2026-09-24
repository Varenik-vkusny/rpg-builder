// Тексты для модели: правила мира и просьба автора.
import type { AssistantRequest } from "./handler.ts";
import type { World } from "./world.ts";
import { objectsByKey } from "./world.ts";

export function systemPrompt(w: World, scope: Set<string>): string {
  const all = objectsByKey(w);
  const list = [...scope]
    .map((k) => `- ${k} — «${all.get(k)!.title}»`)
    .join("\n");
  return `Ты — ассистент правок мира RPG. Автор описывает изменение одной фразой, ты составляешь план изменений.
В базу ты не пишешь: план увидит автор, код проверит его на копии мира, и только автор решит, применять ли.

Мир «${w.title}». Сеттинг: ${w.setting || "—"}. Тон: ${w.tone || "—"}. Уровни мира: ${w.level_min}–${w.level_max}.

Область правки — только эти объекты (вид:slug):
${list}
Менять, удалять и упоминать можно только их и объекты, которые план сам создаёт. Остальной мир тебе не виден.
Поля и связи объектов читай инструментами read_object и find_in_scope. Итог отдай одним вызовом propose_plan.

Операции плана:
- location, item, character, quest: create / update / delete по slug. Новый slug — латиница, цифры и «_» (ashen_drowned), не совпадает с существующими.
- loot (добыча врага): character + item, поле chance (0 < шанс ≤ 100). update меняет шанс, delete убирает.
- quest_step: quest + position (с 1). create — только в конец (position = число шагов + 1); delete сдвигает следующие шаги; поля step_kind, target (slug), amount. С target всегда указывай и step_kind.
- quest_reward: quest + item, create / delete.
В fields null значит «не задаю / не меняю». role и kind задаются только при создании.

Правила мира:
- Локация: title, description, level_min ≤ level_max.
- Предмет: kind weapon|armor|consumable|quest|misc, rarity common|uncommon|rare|epic|legendary, level ≥ 1, price ≥ 0. Урон (damage) только у оружия, защита (defense) только у брони.
- Персонаж: role npc (житель) | merchant | enemy; level ≥ 1, hp ≥ 1, attack ≥ 0; location — slug локации. Добыча только у врага.
- Квест: giver — житель (npc); шаги talk (персонаж), kill N (только враг), collect N (предмет), visit (локация); у квеста хотя бы один шаг.
- Потолок урона оружия: 4 + уровень × 2 × множитель редкости (1.0 / 1.2 / 1.5 / 1.9 / 2.4).
- Потолок атаки врага: 4 + уровень × 2. Уровень врага не выше верхнего уровня его локации.
- Каждый предмет должен выпадать из врага или выдаваться наградой.
Затрагивай всё связанное: если врага переселили, проверь квесты, где его надо убить, и его добычу.`;
}

export function userPrompt(req: AssistantRequest): string {
  const ask = `Область: ${req.scope.type}:${req.scope.slug}.\nПросьба автора: ${req.request}`;
  if (req.attempt === 0) return ask;
  return `${ask}

Твой прошлый план проверка на копии мира не пропустила. Исправь его и отдай целиком заново.
Прошлый план:
${JSON.stringify(req.previous_plan)}
Проблемы:
${req.problems.map((p) => `- ${p}`).join("\n")}`;
}
