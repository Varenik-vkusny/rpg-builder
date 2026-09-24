// Связи на копии мира: добыча врага, шаги квеста, награды.
part of 'plan_apply.dart';

extension _Links on _Copy {
  List<FieldChange> _loot(PlanOp op) {
    final ci = _at(characters, (x) => x.slug, op.character, 'персонажа');
    final c = characters[ci];
    final itemId = _idOf('item', _need(op.item, 'предмет'));
    final at = c.loot.indexWhere((l) => l.itemId == itemId);
    final loot = [...c.loot];
    final before = at < 0 ? null : loot[at].chance;
    double? after;
    switch (op.action) {
      case OpAction.create:
        if (c.role != Role.enemy) {
          throw const _OpError('добыча бывает только у врага');
        }
        if (at >= 0) throw const _OpError('этот предмет уже в добыче');
        after = _chance(op);
        loot.add(LootDrop(itemId: itemId, chance: after));
      case OpAction.update:
        if (at < 0) throw const _OpError('такой добычи нет');
        after = _chance(op);
        loot[at] = LootDrop(itemId: itemId, chance: after);
      case OpAction.delete:
        if (at < 0) throw const _OpError('такой добычи нет');
        loot.removeAt(at);
    }
    characters[ci] = Character(
      id: c.id,
      slug: c.slug,
      title: c.title,
      description: c.description,
      role: c.role,
      locationId: c.locationId,
      loot: loot,
      level: c.level,
      hp: c.hp,
      attack: c.attack,
    );
    return _diff({'chance': (before, after)});
  }

  double _chance(PlanOp op) {
    final v = _need(op.number('chance'), 'шанс');
    if (!LootDrop.validChance(v)) {
      throw const _OpError('шанс — больше 0 и не больше 100');
    }
    return v;
  }

  List<FieldChange> _step(PlanOp op) {
    final qi = _at(quests, (x) => x.slug, op.quest, 'квеста');
    final q = quests[qi];
    final steps = [...q.steps];
    final pos = _need(op.position, 'номер шага');
    final old = pos >= 1 && pos <= steps.length ? steps[pos - 1] : null;
    QuestStep? step;
    if (op.action == OpAction.create && pos != steps.length + 1) {
      throw _OpError('новый шаг — только в конец, номер ${steps.length + 1}');
    }
    if (op.action != OpAction.create && old == null) {
      throw _OpError('шага $pos нет');
    }
    if (op.action == OpAction.delete) {
      steps.removeAt(pos - 1);
    } else {
      final kind = StepKind.values.byName(
        op.str('step_kind') ?? old?.kind.name ?? _missing('вид шага'),
      );
      final target = op.str('target');
      if (target == null &&
          (old == null ||
              stepTargetType(kind.name) != stepTargetType(old.kind.name))) {
        throw const _OpError('не задана цель шага');
      }
      final targetId = target == null
          ? old!.targetId
          : _idOf(stepTargetType(kind.name), target);
      if (kind == StepKind.kill &&
          characters.firstWhere((c) => c.id == targetId).role != Role.enemy) {
        throw const _OpError('убить можно только врага');
      }
      final amount = kind.counted
          ? _int(
              op,
              'amount',
              old?.amount ?? _need(op.integer('amount'), 'количество'),
              min: 1,
            )
          : null;
      step = QuestStep(kind: kind, targetId: targetId, amount: amount);
      op.action == OpAction.create ? steps.add(step) : steps[pos - 1] = step;
    }
    quests[qi] = _withQuest(q, steps: steps);
    return [
      FieldChange(
        'Шаг $pos',
        old == null ? null : labels.step(old),
        step == null ? null : labels.step(step),
      ),
    ];
  }

  List<FieldChange> _reward(PlanOp op) {
    final qi = _at(quests, (x) => x.slug, op.quest, 'квеста');
    final q = quests[qi];
    final itemId = _idOf('item', _need(op.item, 'предмет'));
    final has = q.rewardIds.contains(itemId);
    if (op.action == OpAction.update) {
      throw const _OpError('награду можно только добавить или убрать');
    }
    if (op.action == OpAction.create && has) {
      throw const _OpError('такая награда уже есть');
    }
    if (op.action == OpAction.delete && !has) {
      throw const _OpError('такой награды нет');
    }
    quests[qi] = _withQuest(
      q,
      rewardIds: op.action == OpAction.create
          ? [...q.rewardIds, itemId]
          : q.rewardIds.where((r) => r != itemId).toList(),
    );
    return const [];
  }
}
