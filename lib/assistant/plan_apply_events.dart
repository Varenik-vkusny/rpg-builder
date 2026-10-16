// События на копии мира: само событие, враги с числом, предметы.
part of 'plan_apply.dart';

extension _Events on _Copy {
  List<FieldChange> _event(PlanOp op) {
    final i = _slot(op, events, (x) => x.slug, 'события');
    final old = i < 0 ? null : events[i];
    if (op.action == OpAction.delete) {
      // Враги и предметы события уходят вместе с ним; квест, чей шаг ведёт к нему, — нет.
      _removeUnreferenced(events, i, old!.id, old.title);
      return const [];
    }
    final loc = op.str('location');
    final locationId = loc == null ? old?.locationId : _idOf('location', loc);
    final e = Event(
      id: old?.id ?? 'new-event-${op.slug}',
      slug: op.slug!,
      title: op.str('title') ?? old?.title ?? _missing('название'),
      description: op.str('description') ?? old?.description ?? '',
      locationId: locationId ?? _missing('место события'),
      enemies: old?.enemies ?? const [],
      items: old?.items ?? const [],
    );
    i < 0 ? events.add(e) : events[i] = e;
    return _diff({
      'title': (old?.title, e.title),
      'description': (old?.description, e.description),
      'location': (old?.locationId, e.locationId),
    });
  }

  /// Событие с новыми врагами и предметами; остальное — как было.
  void _setLinks(int ei, {List<EventEnemy>? enemies, List<EventItem>? items}) {
    final e = events[ei];
    events[ei] = Event(
      id: e.id,
      slug: e.slug,
      title: e.title,
      description: e.description,
      locationId: e.locationId,
      enemies: enemies ?? e.enemies,
      items: items ?? e.items,
    );
  }

  List<FieldChange> _eventEnemy(PlanOp op) {
    final ei = _at(events, (x) => x.slug, op.event, 'события');
    final charId = _idOf('character', _need(op.character, 'враг'));
    final enemies = [...events[ei].enemies];
    final at = enemies.indexWhere((x) => x.characterId == charId);
    int? before = at < 0 ? null : enemies[at].amount;
    int? after;
    switch (op.action) {
      case OpAction.create:
        if (characters.firstWhere((c) => c.id == charId).role != Role.enemy) {
          throw const _OpError('в событии стоят только враги');
        }
        if (at >= 0) throw const _OpError('этот враг уже в событии');
        after = _int(
          op,
          'amount',
          _need(op.integer('amount'), 'число'),
          min: 1,
        );
        enemies.add(EventEnemy(characterId: charId, amount: after));
      case OpAction.update:
        if (at < 0) throw const _OpError('такого врага в событии нет');
        after = _int(
          op,
          'amount',
          _need(op.integer('amount'), 'число'),
          min: 1,
        );
        enemies[at] = EventEnemy(
          id: enemies[at].id,
          characterId: charId,
          amount: after,
        );
      case OpAction.delete:
        if (at < 0) throw const _OpError('такого врага в событии нет');
        enemies.removeAt(at);
    }
    _setLinks(ei, enemies: enemies);
    if (before == after) return const [];
    return [
      FieldChange(
        fieldLabel('amount'),
        before == null ? null : '× $before',
        after == null ? null : '× $after',
      ),
    ];
  }

  List<FieldChange> _eventItem(PlanOp op) {
    final ei = _at(events, (x) => x.slug, op.event, 'события');
    final itemId = _idOf('item', _need(op.item, 'предмет'));
    final items = [...events[ei].items];
    final at = items.indexWhere((x) => x.itemId == itemId);
    switch (op.action) {
      case OpAction.create:
        if (at >= 0) throw const _OpError('этот предмет уже в событии');
        items.add(EventItem(itemId: itemId));
      case OpAction.update:
        throw const _OpError(
          'предмет события можно только добавить или убрать',
        );
      case OpAction.delete:
        if (at < 0) throw const _OpError('такого предмета в событии нет');
        items.removeAt(at);
    }
    _setLinks(ei, items: items);
    return const [];
  }
}
