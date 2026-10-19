// Холст мира (5е): связи объектов, снятые со снимка мира. Чистый Dart.
// Каждая связь — одна строка данных: выдающий квеста, шаг, награда, добыча, враг и предмет события.
import '../check/world_check.dart';
import '../content/quest.dart';

/// Связь объектов [a] и [b]. Слово всегда про тот конец, рядом с которым стоит (решение
/// владельца 19.10): на [b] — [label] («Кирка — выпадает 35%»), на [a] — [back]
/// («Слизень — роняет 35%»). [step] — номер шага квеста; [chip] — короткая надпись значка
/// на [b] в покое («35%», «×3»; у шага — номер).
class HolstLink {
  const HolstLink(
    this.a,
    this.b,
    this.label, {
    String? back,
    this.step,
    this.chip = '',
  }) : back = back ?? label;

  final String a;
  final String b;
  final String label;
  final String back;
  final int? step;
  final String chip;

  /// Слово связи на конце [id]: что этот объект в связи.
  String wordOn(String id) => id == b ? label : back;

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
    if (q.giverId case final g?)
      HolstLink(q.id, g, 'выдаёт', back: 'его квест'),
    for (final (i, s) in q.steps.indexed)
      HolstLink(q.id, s.targetId, stepLabel(s), step: i + 1, chip: '${i + 1}'),
    for (final r in q.rewardIds)
      HolstLink(q.id, r, 'в награду', back: 'даёт в награду'),
  ],
  for (final c in w.characters)
    for (final l in c.loot)
      HolstLink(
        c.id,
        l.itemId,
        'выпадает ${_num(l.chance)}%',
        back: 'роняет ${_num(l.chance)}%',
        chip: '${_num(l.chance)}%',
      ),
  for (final e in w.events) ...[
    for (final x in e.enemies)
      HolstLink(
        e.id,
        x.characterId,
        'в сцене ×${x.amount}',
        back: 'враги ×${x.amount}',
        chip: '×${x.amount}',
      ),
    for (final i in e.itemIds)
      HolstLink(e.id, i, 'лежит в сцене', back: 'лежит'),
  ],
];

/// Связи выбранного по объектам: с кем связан и кем тот приходится («Бригадир» → «выдаёт»).
/// Порядок — как в мире; один объект — одна плитка. Шаг квеста — с номером.
List<({String other, List<String> words})> linkGroups(
  String id,
  List<HolstLink> links,
) {
  final out = <String, List<String>>{};
  for (final l in links) {
    if (l.touches(id)) {
      final o = l.other(id);
      out.putIfAbsent(o, () => []).add(stepWord(l, l.wordOn(o)));
    }
  }
  return [for (final e in out.entries) (other: e.key, words: e.value)];
}

/// Слово с номером шага: «шаг 4: поговорить»; не шаг — как есть.
String stepWord(HolstLink l, String word) =>
    l.step == null ? word : 'шаг ${l.step}: $word';

/// Соседи выбранного по связям — вместе с ним самим.
Set<String> neighbours(String? id, List<HolstLink> links) => {
  if (id != null) ...{
    id,
    for (final l in links)
      if (l.touches(id)) l.other(id),
  },
};
