// Проверка мира — чистый Dart над снимком мира в памяти, без Flutter и базы.
// Тот же код проверит и копию мира с планом ассистента (VISION.md, правило 7).
import '../content/character.dart';
import '../content/event.dart';
import '../content/item.dart';
import '../content/location.dart';
import '../content/quest.dart';
import 'nesting_rules.dart';
import 'warning_rules.dart';

/// Мир целиком в памяти: всё, что видят правила.
class WorldSnapshot {
  const WorldSnapshot({
    this.locations = const [],
    this.items = const [],
    this.characters = const [],
    this.quests = const [],
    this.events = const [],
  });

  final List<Location> locations;
  final List<Item> items;
  final List<Character> characters;
  final List<Quest> quests;
  final List<Event> events;

  /// Названия всех объектов мира по id.
  Map<String, String> get titles => {
    for (final l in locations) l.id: l.title,
    for (final i in items) i.id: i.title,
    for (final c in characters) c.id: c.title,
    for (final q in quests) q.id: q.title,
    for (final e in events) e.id: e.title,
  };
}

/// Ошибка блокирует запись мира (правило 4), предупреждение — нет.
enum Severity {
  error('Ошибка'),
  warning('Предупреждение');

  const Severity(this.label);
  final String label;
}

/// Одна найденная проблема: какое правило, на каком объекте, что не так.
class Problem {
  const Problem(this.severity, this.rule, this.objectId, this.message);

  final Severity severity;

  /// Короткий код правила: `broken_link`, `quest_no_steps`, …
  final String rule;
  final String objectId;
  final String message;

  @override
  String toString() => '${severity.name}/$rule($objectId): $message';
}

/// Все проблемы мира одним списком: сначала ошибки, потом предупреждения.
List<Problem> checkWorld(WorldSnapshot w) => [
  ...errorRules(w),
  ...warningRules(w),
];

/// Ошибки: ссылка на несуществующий объект, квест без шагов или выдающего,
/// событие без места, вложенность мест (место в самом себе, глубже трёх уровней).
List<Problem> errorRules(WorldSnapshot w) {
  final ids = _Ids(w);
  return [
    for (final l in w.locations)
      if (l.parentId != null)
        ?ids.link(l.id, l.title, 'родитель', l.parentId!, ids.locations),
    ...nestingErrors(w),
    for (final c in w.characters) ...[
      if (c.locationId != null)
        ?ids.link(c.id, c.title, 'локация', c.locationId!, ids.locations),
      for (final l in c.loot)
        ?ids.link(c.id, c.title, 'добыча', l.itemId, ids.items),
    ],
    for (final q in w.quests) ..._questErrors(q, ids),
    for (final e in w.events) ..._eventErrors(e, ids),
  ];
}

List<Problem> _eventErrors(Event e, _Ids ids) => [
  if (e.locationId == null)
    Problem(
      Severity.error,
      'event_no_location',
      e.id,
      '«${e.title}»: у события нет места',
    )
  else
    ?ids.link(e.id, e.title, 'место', e.locationId!, ids.locations),
  for (final x in e.enemies)
    ?ids.link(e.id, e.title, 'враг', x.characterId, ids.characters),
  for (final x in e.items)
    ?ids.link(e.id, e.title, 'предмет', x.itemId, ids.items),
];

List<Problem> _questErrors(Quest q, _Ids ids) => [
  if (q.giverId == null)
    Problem(
      Severity.error,
      'quest_no_giver',
      q.id,
      '«${q.title}»: у квеста нет выдающего',
    )
  else
    ?ids.link(q.id, q.title, 'выдающий', q.giverId!, ids.characters),
  if (q.steps.isEmpty)
    Problem(
      Severity.error,
      'quest_no_steps',
      q.id,
      '«${q.title}»: у квеста нет шагов',
    ),
  for (final (i, s) in q.steps.indexed)
    ?ids.link(q.id, q.title, 'шаг ${i + 1}', s.targetId, switch (s.kind) {
      StepKind.talk || StepKind.kill => ids.characters,
      StepKind.collect => ids.items,
      StepKind.visit => ids.locations,
      StepKind.event => ids.events,
    }),
  for (final r in q.rewardIds)
    ?ids.link(q.id, q.title, 'награда', r, ids.items),
];

/// id объектов мира по видам — куда может вести ссылка.
class _Ids {
  _Ids(WorldSnapshot w)
    : locations = {for (final l in w.locations) l.id},
      items = {for (final i in w.items) i.id},
      characters = {for (final c in w.characters) c.id},
      events = {for (final e in w.events) e.id};

  final Set<String> locations;
  final Set<String> items;
  final Set<String> characters;
  final Set<String> events;

  /// Ошибка, если [id] не найден среди [pool]; иначе null.
  Problem? link(
    String owner,
    String ownerTitle,
    String what,
    String id,
    Set<String> pool,
  ) => pool.contains(id)
      ? null
      : Problem(
          Severity.error,
          'broken_link',
          owner,
          '«$ownerTitle»: $what ссылается на несуществующий объект',
        );
}
