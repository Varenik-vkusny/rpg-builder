// Места внутри места (02.10, решение владельца): план описывает место заново, а места внутри
// него (в области) не трогает — бесплатная модель так делала дважды на «Затопи копи».
// Сервер не угадывает за автора: спрашивает «менять и их?». Ответ «да» возвращает план модели.
import type { Answer } from "./handler.ts";
import type { AuthorQuestion, Plan } from "./plan.ts";
import type { World, WorldLocation } from "./world.ts";
import { key } from "./world.ts";

/// Начало вопроса — по нему сервер узнаёт свой вопрос среди ответов автора.
export const INNER_QUESTION_PREFIX = "Места внутри";
const YES = "Да, и их тоже";
const NO = "Нет, только";

/// Места внутри мест, чьё описание план меняет, — если сами они в план не попали.
export function innerPlacesMissed(plan: Plan, w: World, scope: Set<string>): WorldLocation[] {
  const touched = new Set(plan.ops.filter((o) => o.type === "location").map((o) => o.slug));
  const redescribed = plan.ops
    .filter((o) => o.type === "location" && o.action === "update" && o.fields.description != null)
    .map((o) => o.slug);
  return w.locations.filter((l) =>
    l.parent != null &&
    redescribed.includes(l.parent) &&
    scope.has(key("location", l.slug)) &&
    !touched.has(l.slug)
  );
}

export function innerQuestion(missed: WorldLocation[], w: World): AuthorQuestion {
  const names = (ls: WorldLocation[]) => ls.map((l) => `«${l.title}»`).join(", ");
  const parents = w.locations.filter((p) => missed.some((m) => m.parent === p.slug));
  return {
    question: `${INNER_QUESTION_PREFIX} ${names(parents)} — ${names(missed)} — план не меняет. Изменить и их?`,
    options: [
      { label: YES, description: `ассистент опишет, что стало с ${names(missed)}` },
      { label: `${NO} ${names(parents)}`, description: "места внутри останутся как есть" },
    ],
  };
}

/// Ответ автора на этот вопрос: «yes», «no» или null — не спрашивали.
export function innerAnswer(answers: Answer[]): "yes" | "no" | null {
  const a = answers.find((x) => x.question.startsWith(INNER_QUESTION_PREFIX));
  if (!a) return null;
  return a.answer.startsWith(YES) ? "yes" : "no";
}

/// Что сказать модели, когда автор ответил «да», а места в плане всё ещё нет.
export function innerRejectLines(missed: WorldLocation[]): string[] {
  return [
    "Автор ответил: менять и места внутри. В плане их нет:",
    ...missed.map((l) => `- location:${l.slug} «${l.title}» — добавь операцию update с новым description`),
    "Отдай план целиком заново.",
  ];
}

// Удаление жителя (02.10, решение владельца): модель удаляла жителя, спросив автора о другом.
// Сервер спрашивает сам, если ни один вопрос автору не называл этого жителя.
export const RESIDENT_QUESTION_PREFIX = "Удалить жителя";
const KEEP = "Нет, оставить";

// Место не изменено (02.10, решение владельца): прогон v38 — модель спросила про слизня и не
// тронула ни одного места. Сервер спрашивает ««Копи» в плане не изменено — изменить описание?».
export const UNCHANGED_MARK = "в плане не изменено";
const REDESCRIBE = "Да, описать заново";

/// Вопросы, которые задаёт сервер, а не модель: лимит вопросов модели они не съедают.
export const SERVER_QUESTIONS = [INNER_QUESTION_PREFIX, RESIDENT_QUESTION_PREFIX, UNCHANGED_MARK];
/// Свой вопрос сервер узнаёт только по началу: модель не протащит вопрос мимо лимита (ревью 02.10).
const isUnchangedQuestion = (q: string) => new RegExp(`^«[^»]+» ${UNCHANGED_MARK}`).test(q);
export const isServerQuestion = (q: string) =>
  q.startsWith(INNER_QUESTION_PREFIX) || q.startsWith(RESIDENT_QUESTION_PREFIX) || isUnchangedQuestion(q);

export function unchangedQuestion(l: WorldLocation): AuthorQuestion {
  return {
    question: `«${l.title}» ${UNCHANGED_MARK} — изменить описание?`,
    options: [
      { label: REDESCRIBE, description: `ассистент опишет, что стало с «${l.title}»` },
      { label: "Нет, оставить как есть", description: "план уйдёт без этого места" },
    ],
  };
}

/// Место, названное в просьбе («затопи копи» → Копи), если план не описывает заново ни одно из
/// названных: место области и места внутри него. Просьба не называет места — не спрашиваем:
/// «уменьши атаку слизня» не про описание места.
function untouchedNamed(plan: Plan, w: World, scope: Set<string>, root: WorldLocation | null, request: string) {
  if (!root) return null;
  const text = request.toLowerCase();
  const named = [root, ...w.locations.filter((l) => l.parent === root.slug && scope.has(key("location", l.slug)))]
    .filter((l) => names(text, l.title));
  if (named.length === 0) return null;
  const slugs = new Set(named.map((l) => l.slug));
  const described = plan.ops.some((o) =>
    o.type === "location" && o.action === "update" && o.fields.description != null && slugs.has(o.slug ?? "")
  );
  return described ? null : named[0];
}

type Resident = { slug: string; title: string };

/// Основы слов имени: «Пепельный слизень» → «пепе», «слиз». Падеж не важен: «слизнем» — тоже он.
export const nameStems = (title: string) =>
  title.toLowerCase().split(/[^\p{L}\d]+/u).filter((w) => w.length > 0).map((w) => w.slice(0, 4));

/// Текст называет имя: каждое слово имени — начало какого-то слова текста по основе.
/// «Копи» есть в «затопи копи», но не в «скопируй» и «накопи» (ревью 02.10).
const names = (text: string, title: string) => {
  const words = text.toLowerCase().split(/[^\p{L}\d]+/u);
  return nameStems(title).every((s) => words.some((w) => w.startsWith(s)));
};

/// Вопрос (с ответом) называет жителя — все слова его имени. Свой вопрос про места внутри
/// сервер не считает: «Хозяин копи» не спрошен оттого, что спросили про «Копи» (ревью 02.10).
const mentions = (a: Answer, r: Resident) => {
  if (a.question.startsWith(INNER_QUESTION_PREFIX) || isUnchangedQuestion(a.question)) return false;
  const text = `${a.question} ${a.answer}`.toLowerCase();
  return names(text, r.title);
};

function deletedResidents(plan: Plan, w: World): Resident[] {
  const del = new Set(plan.ops.filter((o) => o.type === "character" && o.action === "delete").map((o) => o.slug));
  return w.characters.filter((c) => del.has(c.slug)).map((c) => ({ slug: c.slug, title: c.title }));
}

export function residentQuestion(rs: Resident[]): AuthorQuestion {
  const names = rs.map((r) => `«${r.title}»`).join(", ");
  return {
    question: `${RESIDENT_QUESTION_PREFIX} ${names}? План убирает его из мира.`,
    options: [
      { label: "Да, удалить", description: `${names} исчезнет вместе с добычей` },
      { label: KEEP, description: "ассистент оставит жителя — переселит или изменит" },
    ],
  };
}

/// Что сервер делает с планом до автора: спросить, вернуть модели или пропустить (null).
export function authorCheck(
  plan: Plan,
  w: World,
  scope: Set<string>,
  answers: Answer[],
  mayAsk: boolean,
  root: WorldLocation | null = null,
  request = "",
): { ask: AuthorQuestion } | { reject: string[] } | null {
  const untouched = untouchedNamed(plan, w, scope, root, request);
  if (untouched) {
    const a = answers.find((x) => isUnchangedQuestion(x.question));
    if (a?.answer.startsWith(REDESCRIBE)) {
      return {
        reject: [
          `Автор ответил: опиши заново location:${untouched.slug} «${untouched.title}» — операцией update с новым description.`,
          "Отдай план целиком заново.",
        ],
      };
    }
    if (!a && mayAsk) return { ask: unchangedQuestion(untouched) };
  }
  const missed = innerPlacesMissed(plan, w, scope);
  const said = innerAnswer(answers);
  if (missed.length > 0 && said === "yes") return { reject: innerRejectLines(missed) };
  if (missed.length > 0 && said === null && mayAsk) return { ask: innerQuestion(missed, w) };

  const deleted = deletedResidents(plan, w);
  const refused = deleted.filter((r) =>
    answers.some((a) => a.question.startsWith(RESIDENT_QUESTION_PREFIX) && mentions(a, r) && a.answer.startsWith(KEEP))
  );
  if (refused.length > 0) {
    return {
      reject: [
        ...refused.map((r) => `Автор не разрешил удалять character:${r.slug} «${r.title}» — оставь его (переселить, изменить).`),
        "Отдай план целиком заново.",
      ],
    };
  }
  const unasked = deleted.filter((r) => !answers.some((a) => mentions(a, r)));
  if (unasked.length === 0) return null;
  // О жителях сервер спрашивает один раз — всех сразу; кого не было в том вопросе, не удаляем.
  const askedBefore = answers.some((a) => a.question.startsWith(RESIDENT_QUESTION_PREFIX));
  if (mayAsk && !askedBefore) return { ask: residentQuestion(unasked) };
  if (!askedBefore) return null;
  return {
    reject: [
      ...unasked.map((r) => `Автора не спрашивали об удалении character:${r.slug} «${r.title}» — оставь его (переселить, изменить).`),
      "Отдай план целиком заново.",
    ],
  };
}
