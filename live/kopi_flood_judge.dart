// Прибор приёмки «Затопи копи» (владелец, 01.10.2026) — по смыслу плана, а не по числу операций:
// 1) план меняет описание места внутри копей (Штольня №3), а не только её жителей;
// 2) удалить жителя можно, только спросив автора.
// Живой прогон (kopi_flood_live_test.dart) и сохранённый прошлый прогон
// (test/fixtures/kopi_flood_2026-10-01.json) судятся одной функцией.
import 'package:rpg_builder/assistant/plan.dart';

/// Места внутри копей в мире живого прогона.
const kopiInner = {'shtolnya_3'};

/// Что не так с планом «затопи копи»; пусто — приёмка пройдена.
List<String> judgeKopiFlood(Plan plan, {required int questionsAsked}) => [
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
        questionsAsked == 0)
      'житель «${o.slug}» удалён без вопроса автору',
];
