// Прибор приёмки «Затопи копи» (владелец, 01.10.2026) — по смыслу плана, а не по числу операций:
// 1) план меняет описание места внутри копей (Штольня №3), а не только её жителей;
// 2) удалить жителя можно, только спросив автора именно о нём (вопрос или варианты называют
//    жителя) — вопрос о другом не считается (дыра, найденная 02.10 на прогоне v35).
// Живой прогон (kopi_flood_live_test.dart) и сохранённый прошлый прогон
// (test/fixtures/kopi_flood_2026-10-01.json) судятся одной функцией.
import 'package:rpg_builder/assistant/plan.dart';

/// Места внутри копей в мире живого прогона.
const kopiInner = {'shtolnya_3'};

/// Что не так с планом «затопи копи»; пусто — приёмка пройдена. [questions] — тексты вопросов
/// автору вместе с вариантами, [titles] — имена жителей по slug.
List<String> judgeKopiFlood(
  Plan plan, {
  required List<String> questions,
  required Map<String, String> titles,
}) => [
  if (!plan.ops.any(
    (o) =>
        o.type == OpType.location &&
        o.action == OpAction.update &&
        kopiInner.contains(o.slug) &&
        o.fields.containsKey('description'),
  ))
    'описание места внутри копей не изменилось (${kopiInner.join(', ')})',
  for (final o in plan.ops)
    if (o.type == OpType.character &&
        o.action == OpAction.delete &&
        !askedAbout(questions, titles[o.slug] ?? o.slug!))
      'житель «${o.slug}» удалён без вопроса автору о нём',
];

/// Вопрос называет жителя — все слова имени по основе («Пепельный слизень» → «пепе», «слиз»;
/// падеж не важен). Вопрос сервера про места внутри не в счёт. То же правило, что на сервере
/// (`supabase/functions/assistant/inner_places.ts`, `mentions`).
bool askedAbout(List<String> questions, String title) {
  final stems = [
    for (final w in title.toLowerCase().split(
      RegExp(r'[^\p{L}\d]+', unicode: true),
    ))
      if (w.isNotEmpty) w.substring(0, w.length < 4 ? w.length : 4),
  ];
  return questions.any(
    (q) =>
        !q.startsWith('Места внутри') &&
        stems.every((s) => q.toLowerCase().contains(s)),
  );
}
