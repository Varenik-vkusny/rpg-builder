// Правила вложенности мест (5а) — часть той же проверки мира (правило 7).
// Ошибки: место в самом себе, глубже трёх уровней. Предупреждение: уровни вне родителя.
// Битый родитель — общая ошибка ссылки (world_check.dart), удаление места
// с вложенными не пускает referencesTo (как и любую ссылку).
import '../content/nesting.dart';
import 'world_check.dart';

List<Problem> nestingErrors(WorldSnapshot w) => [
  for (final l in w.locations)
    if (inCycle(w.locations, l))
      Problem(
        Severity.error,
        'location_cycle',
        l.id,
        '«${l.title}» лежит само в себе — вложенность замкнулась',
      )
    else if (depthOf(w.locations, l) > maxNestingDepth)
      Problem(
        Severity.error,
        'location_too_deep',
        l.id,
        '«${pathOf(w.locations, l)}»: глубже $maxNestingDepth уровней',
      ),
];

List<Problem> nestingWarnings(WorldSnapshot w) {
  final all = byId(w.locations);
  return [
    for (final l in w.locations)
      if (all[l.parentId] case final p?
          when l.levelMin < p.levelMin || l.levelMax > p.levelMax)
        Problem(
          Severity.warning,
          'location_levels_outside_parent',
          l.id,
          '«${l.title}»: уровни ${l.levelMin}–${l.levelMax} вне уровней '
              '«${p.title}» (${p.levelMin}–${p.levelMax})',
        ),
  ];
}
