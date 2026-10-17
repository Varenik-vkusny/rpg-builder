// Холст мира (5е): нити — связи объектов, снятые со снимка мира. Чистый Dart.
// Каждая нить — одна строка данных: выдающий квеста, шаг, награда, добыча, враг и предмет события.
import '../check/world_check.dart';
import '../content/quest.dart';

/// Нить между объектами [a] и [b]: подпись словами автора («убить ×3», «роняет 35%»).
/// [loot] — добыча, рисуется пунктиром.
class HolstLink {
  const HolstLink(this.a, this.b, this.label, {this.loot = false});

  final String a;
  final String b;
  final String label;
  final bool loot;

  bool touches(String id) => a == id || b == id;
  String other(String id) => a == id ? b : a;

  /// Одна и та же связь между теми же концами — для сравнения «было → стало».
  String get key => '$a>$b>$label';
}

/// «35.0» → «35», «12.5» → «12.5».
String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

String stepLabel(QuestStep s) => switch (s.kind) {
  StepKind.talk => 'поговорить',
  StepKind.kill => 'убить ×${s.amount ?? 1}',
  StepKind.collect => 'собрать ×${s.amount ?? 1}',
  StepKind.visit => 'прийти',
  StepKind.event => 'пройти',
};

/// Все связи мира. Концы — id объектов; цель шага «прийти» — место.
List<HolstLink> worldLinks(WorldSnapshot w) => [
  for (final q in w.quests) ...[
    if (q.giverId case final g?) HolstLink(q.id, g, 'выдаёт'),
    for (final s in q.steps) HolstLink(q.id, s.targetId, stepLabel(s)),
    for (final r in q.rewardIds) HolstLink(q.id, r, 'награда'),
  ],
  for (final c in w.characters)
    for (final l in c.loot)
      HolstLink(c.id, l.itemId, 'роняет ${_num(l.chance)}%', loot: true),
  for (final e in w.events) ...[
    for (final x in e.enemies)
      HolstLink(e.id, x.characterId, 'враги ×${x.amount}'),
    for (final i in e.itemIds) HolstLink(e.id, i, 'лежит'),
  ],
];

/// Нижняя строка выбранного: «убить ×3 · Обвал / роняет 35% · Ключ». Связей нет — null.
String? linksLine(
  String id,
  List<HolstLink> links,
  String Function(String id) title,
) {
  final mine = [
    for (final l in links)
      if (l.touches(id)) '${l.label} · ${title(l.other(id))}',
  ];
  return mine.isEmpty ? null : mine.join('  /  ');
}

/// Соседи выбранного по нитям — вместе с ним самим.
Set<String> neighbours(String? id, List<HolstLink> links) => {
  if (id != null) ...{
    id,
    for (final l in links)
      if (l.touches(id)) l.other(id),
  },
};
