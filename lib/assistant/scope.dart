// Область правки в приложении — второй замок после серверной функции
// (supabase/functions/assistant/world.ts, plan.ts). Правило то же:
// объект и всё, что связано с ним не дальше двух связей.
import '../check/world_check.dart';
import '../content/quest.dart';
import 'assistant_service.dart';
import 'plan.dart';

const scopeDepth = 2;

/// Ключ объекта: `character:ash_slime`.
String scopeKey(String type, String slug) => '$type:$slug';

String stepTargetType(String stepKind) => switch (stepKind) {
  'collect' => 'item',
  'visit' => 'location',
  _ => 'character',
};

/// Ключи области. Корня нет в мире — пусто.
Set<String> scopeOf(WorldSnapshot w, Scope scope) {
  final keyById = <String, String>{
    for (final l in w.locations) l.id: scopeKey('location', l.slug),
    for (final i in w.items) i.id: scopeKey('item', i.slug),
    for (final c in w.characters) c.id: scopeKey('character', c.slug),
    for (final q in w.quests) q.id: scopeKey('quest', q.slug),
  };
  final near = <String, Set<String>>{};
  void link(String aId, String? bId) {
    final a = keyById[aId], b = keyById[bId];
    if (a == null || b == null) return;
    near.putIfAbsent(a, () => {}).add(b);
    near.putIfAbsent(b, () => {}).add(a);
  }

  for (final c in w.characters) {
    link(c.id, c.locationId);
    for (final l in c.loot) {
      link(c.id, l.itemId);
    }
  }
  for (final q in w.quests) {
    link(q.id, q.giverId);
    for (final QuestStep s in q.steps) {
      link(q.id, s.targetId);
    }
    for (final r in q.rewardIds) {
      link(q.id, r);
    }
  }
  final root = scopeKey(scope.type.name, scope.slug);
  if (!keyById.containsValue(root)) return {};
  final seen = {root};
  var frontier = [root];
  for (var d = 0; d < scopeDepth; d++) {
    frontier = [
      for (final k in frontier)
        for (final n in near[k] ?? const <String>{})
          if (seen.add(n)) n,
    ];
  }
  return seen;
}

/// Что операция меняет, создаёт и на что ссылается — ключами.
({List<String> changes, String? creates, List<String> refs}) _touched(
  PlanOp op,
) {
  final refs = <String>[
    if (op.str('location') case final l?) scopeKey('location', l),
    if (op.str('giver') case final g?) scopeKey('character', g),
    // Цель без вида шага не проверить по области — такая ссылка не пропускается никогда.
    if (op.str('target') case final t?)
      scopeKey(
        op.str('step_kind') == null
            ? 'шаг-без-вида'
            : stepTargetType(op.str('step_kind')!),
        t,
      ),
  ];
  switch (op.type) {
    case OpType.loot:
      return (
        changes: [scopeKey('character', op.character ?? '')],
        creates: null,
        refs: [...refs, scopeKey('item', op.item ?? '')],
      );
    case OpType.questStep || OpType.questReward:
      return (
        changes: [scopeKey('quest', op.quest ?? '')],
        creates: null,
        refs: [
          ...refs,
          if (op.type == OpType.questReward) scopeKey('item', op.item ?? ''),
        ],
      );
    default:
      final me = scopeKey(op.typeName, op.slug ?? '');
      return op.action == OpAction.create
          ? (changes: const [], creates: me, refs: refs)
          : (changes: [me], creates: null, refs: refs);
  }
}

/// Номера операций (с 0) вне области и что именно вне её.
/// Менять, удалять и упоминать можно область и созданное самим планом.
Map<int, List<String>> outOfScope(Plan plan, Set<String> scope) {
  final created = {for (final op in plan.ops) ?_touched(op).creates};
  return {
    for (final (i, op) in plan.ops.indexed)
      if ([
            ..._touched(op).changes,
            ..._touched(op).refs,
          ].where((k) => !scope.contains(k) && !created.contains(k)).toList()
          case final bad when bad.isNotEmpty)
        i: bad,
  };
}
