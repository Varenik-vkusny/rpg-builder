// Холст мира (5е), «Менять»: план фразы на холсте. Чистый Dart над миром и его копией
// после плана: что новое, что изменено, какие нити новые и изменённые, строки
// «было → стало» и сколько изменений спрятано за каждой дверью.
import '../assistant/plan.dart';
import '../assistant/plan_apply.dart';
import '../check/world_check.dart';
import '../content/nesting.dart';
import 'holst_links.dart';
import 'holst_parts.dart' show Mark;
import 'holst_threads.dart' show ThreadTone;

/// Больше стольких изменений план не проступает по шагу — показывается список.
const planStepsOnCanvas = 6;

/// Подпись объекта целиком — изменилось ли в нём хоть что-то.
Map<String, String> _signatures(WorldSnapshot w) => {
  for (final l in w.locations)
    l.id:
        '${l.title}|${l.description}|${l.levelMin}|${l.levelMax}|${l.parentId}',
  for (final i in w.items)
    i.id:
        '${i.title}|${i.kind}|${i.rarity}|${i.level}|${i.damage}|'
        '${i.defense}|${i.price}',
  for (final c in w.characters)
    c.id:
        '${c.title}|${c.description}|${c.locationId}|${c.level}|${c.hp}|'
        '${c.attack}|${c.loot.map((l) => '${l.itemId}:${l.chance}').join(',')}',
  for (final q in w.quests)
    q.id:
        '${q.title}|${q.description}|${q.giverId}|'
        '${q.steps.map((s) => '${s.kind}:${s.targetId}:${s.amount}').join(',')}|'
        '${q.rewardIds.join(',')}',
  for (final e in w.events)
    e.id:
        '${e.title}|${e.description}|${e.locationId}|'
        '${e.enemies.map((x) => '${x.characterId}:${x.amount}').join(',')}|'
        '${e.itemIds.join(',')}',
};

/// Новое — зелёным, изменённое — пурпуром: по объектам мира.
Map<String, Mark> planMarks(WorldSnapshot was, WorldSnapshot now) {
  final a = _signatures(was), b = _signatures(now);
  return {
    for (final MapEntry(:key, :value) in b.entries)
      if (!a.containsKey(key))
        key: Mark.isNew
      else if (a[key] != value)
        key: Mark.changed,
  };
}

/// Нити плана: связи, которой не было, — зелёная, если у пары не было ни одной связи,
/// и пурпурная, если пара была связана иначе. Ключ — «откуда>куда».
Map<String, ThreadTone> planThreads(WorldSnapshot was, WorldSnapshot now) {
  final old = {for (final l in worldLinks(was)) l.key};
  final pairs = {for (final l in worldLinks(was)) '${l.a}>${l.b}'};
  return {
    for (final l in worldLinks(now))
      if (!old.contains(l.key))
        '${l.a}>${l.b}': pairs.contains('${l.a}>${l.b}')
            ? ThreadTone.changed
            : ThreadTone.isNew,
  };
}

/// Строка плана: объект, что меняется, было → стало; [target] — id на копии для «показать».
class PlanRow {
  const PlanRow({
    required this.title,
    required this.field,
    required this.was,
    required this.now,
    required this.isNew,
    required this.target,
    this.error,
  });

  final String title;
  final String field;
  final String was;
  final String now;
  final bool isNew;
  final String? target;
  final String? error;
}

/// Имя объекта из заголовка операции («Создать · Персонаж «Утопленник»» → Утопленник).
String _name(String title) =>
    RegExp(r'«([^»]+)»').firstMatch(title)?.group(1) ?? title;

/// Новый объект — одной строкой: где и какого уровня.
String _brief(OpResult r) {
  String? f(String label) => r.changes
      .where((c) => c.label == label && c.after != null)
      .firstOrNull
      ?.after;
  final parts = [
    ?f('Локация'),
    ?f('Место'),
    if (f('Уровень') case final l?) 'ур. $l',
  ];
  return parts.isEmpty ? (r.changes.lastOrNull?.after ?? '') : parts.join(', ');
}

/// Связь (добыча, шаг, награда, враг и предмет события) — словом и вторым концом.
const _linkWords = {
  OpType.loot: 'добыча',
  OpType.questStep: 'шаг',
  OpType.questReward: 'награда',
  OpType.eventEnemy: 'враги',
  OpType.eventItem: 'лежит',
};

/// Новая или убранная связь: «Утопленник · добыча — → Ключ 35%».
PlanRow? _linkRow(OpResult r, WorldSnapshot copy) {
  final word = _linkWords[r.op.type];
  if (word == null || r.error != null || r.op.action == OpAction.update) {
    return null;
  }
  final names = RegExp(r'«([^»]+)»').allMatches(r.title).toList();
  final other = names.length > 1 ? names[1].group(1)! : '';
  final value = r.changes.firstOrNull;
  final create = r.op.action == OpAction.create;
  final v = create ? value?.after : value?.before;
  final text = [other, ?v].where((x) => x.isNotEmpty).join(' ');
  return PlanRow(
    title: _name(r.title),
    field: word,
    was: create ? '—' : text,
    now: create ? text : '—',
    isNew: create,
    target: targetOf(r.op, copy),
  );
}

/// Строки плана: новое и убранное — одной строкой, изменённое — строка на каждое поле.
List<PlanRow> planRows(List<OpResult> ops, WorldSnapshot copy) => [
  for (final r in ops)
    if (_linkRow(r, copy) case final link?)
      link
    else if (r.error != null ||
        r.op.action != OpAction.update ||
        r.changes.isEmpty)
      PlanRow(
        title: _name(r.title),
        field: switch (r.op.action) {
          OpAction.create => 'новое',
          OpAction.update => 'изменено',
          OpAction.delete => 'убрано',
        },
        was: r.op.action == OpAction.create ? '—' : '',
        now: switch (r.op.action) {
          OpAction.create => _brief(r),
          OpAction.delete => '—',
          OpAction.update => '',
        },
        isNew: r.op.action == OpAction.create,
        target: targetOf(r.op, copy),
        error: r.error,
      )
    else
      for (final c in r.changes)
        PlanRow(
          title: _name(r.title),
          field: c.label.toLowerCase(),
          was: c.before ?? '—',
          now: c.after ?? '—',
          isNew: false,
          target: targetOf(r.op, copy),
        ),
];

/// Объект операции на копии: сам объект или хозяин связи (враг, квест, событие).
String? targetOf(PlanOp op, WorldSnapshot w) {
  String? by<T>(
    List<T> list,
    String Function(T) slug,
    String Function(T) id,
    String? s,
  ) {
    for (final x in list) {
      if (slug(x) == s) return id(x);
    }
    return null;
  }

  return switch (op.type) {
    OpType.location => by(w.locations, (x) => x.slug, (x) => x.id, op.slug),
    OpType.item => by(w.items, (x) => x.slug, (x) => x.id, op.slug),
    OpType.character => by(w.characters, (x) => x.slug, (x) => x.id, op.slug),
    OpType.quest => by(w.quests, (x) => x.slug, (x) => x.id, op.slug),
    OpType.event => by(w.events, (x) => x.slug, (x) => x.id, op.slug),
    OpType.loot => by(w.characters, (x) => x.slug, (x) => x.id, op.character),
    OpType.questStep ||
    OpType.questReward => by(w.quests, (x) => x.slug, (x) => x.id, op.quest),
    OpType.eventEnemy ||
    OpType.eventItem => by(w.events, (x) => x.slug, (x) => x.id, op.event),
  };
}

/// Сколько изменённых объектов лежит внутри места [doorId] (на любой глубине).
int changesInside(WorldSnapshot w, String doorId, Iterable<String> changed) {
  final places = placeAndInside(w.locations, doorId);
  var n = 0;
  for (final id in changed) {
    final placeOf =
        w.characters.where((c) => c.id == id).firstOrNull?.locationId ??
        w.events.where((e) => e.id == id).firstOrNull?.locationId ??
        (w.locations.any((l) => l.id == id) ? id : null);
    if (placeOf != null && places.contains(placeOf)) n++;
  }
  return n;
}

/// «1 изменение», «3 изменения», «5 изменений».
String changesWord(int n) {
  final d = n % 10, h = n % 100;
  final w = d == 1 && h != 11
      ? 'изменение'
      : d >= 2 && d <= 4 && (h < 12 || h > 14)
      ? 'изменения'
      : 'изменений';
  return '$n $w';
}

/// Копия мира после первых [k] операций плана — для показа по шагу.
WorldSnapshot planPrefix(WorldSnapshot w, Plan plan, int k) => applyToCopy(
  w,
  Plan(summary: plan.summary, ops: plan.ops.take(k).toList()),
).$1;
