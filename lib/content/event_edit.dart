// Правка события вручную (5б.1) — тем же набором изменений, что и у остальных
// объектов (manual_edit.dart): в историю, с откатом.
import 'event.dart';
import 'manual_edit.dart';

/// Враги — по разнице: убрать, поменять число, добавить. Предметы — по разнице.
/// [slugs] — slug персонажей и предметов по id, для подписей в истории.
ManualEdit editEvent(
  String worldId,
  Event old,
  NewEvent now,
  Map<String, String> slugs,
) {
  final row = rowDiff(
    worldId,
    old.id,
    {
      'title': old.title,
      'description': old.description,
      'location_id': old.locationId,
    },
    {
      'title': now.title,
      'description': now.description,
      'location_id': now.locationId,
    },
  );
  String label(String id) => '${old.slug}/${slugs[id] ?? id}';
  final was = {for (final e in old.enemies) e.characterId: e};
  final wasItems = {for (final i in old.items) i.itemId: i};
  return ManualEdit(
    title: 'Правка вручную: ${now.title}',
    slug: old.slug,
    ops: [
      if (row != null) rowOp('update', 'event', old.slug, row),
      ..._enemyOps(worldId, old, now, was, label),
      ..._itemOps(worldId, old, now, wasItems, label),
    ],
    applyTo: (w) =>
        replaceObject(w, old.id, _editedEvent(old, now, was, wasItems)),
  );
}

/// Строка связи события: свой id (у новой его нет) и мир.
Map<String, dynamic> _link(
  String worldId,
  String? id,
  Map<String, dynamic> columns,
) => {'id': ?id, 'project_id': worldId, ...columns};

/// Враги события: убрать, поменять число, добавить.
List<Map<String, dynamic>> _enemyOps(
  String worldId,
  Event old,
  NewEvent now,
  Map<String, EventEnemy> was,
  String Function(String) label,
) {
  final will = {for (final e in now.enemies) e.characterId: e.amount};
  return [
    for (final e in was.values)
      if (!will.containsKey(e.characterId))
        rowOp(
          'delete',
          'event_enemy',
          label(e.characterId),
          _link(worldId, e.id, {}),
        )
      else if (will[e.characterId] != e.amount)
        rowOp(
          'update',
          'event_enemy',
          label(e.characterId),
          _link(worldId, e.id, {'amount': will[e.characterId]}),
        ),
    for (final e in now.enemies)
      if (!was.containsKey(e.characterId))
        rowOp(
          'create',
          'event_enemy',
          label(e.characterId),
          _link(worldId, null, {'event_id': old.id, ...e.toJson()}),
        ),
  ];
}

/// Предметы события: убрать лишние, добавить новые.
List<Map<String, dynamic>> _itemOps(
  String worldId,
  Event old,
  NewEvent now,
  Map<String, EventItem> wasItems,
  String Function(String) label,
) => [
  for (final i in wasItems.values)
    if (!now.itemIds.contains(i.itemId))
      rowOp('delete', 'event_item', label(i.itemId), _link(worldId, i.id, {})),
  for (final id in now.itemIds)
    if (!wasItems.containsKey(id))
      rowOp(
        'create',
        'event_item',
        label(id),
        _link(worldId, null, {'event_id': old.id, 'item_id': id}),
      ),
];

/// Событие после правки: у прежних связей id сохраняются.
Event _editedEvent(
  Event old,
  NewEvent now,
  Map<String, EventEnemy> was,
  Map<String, EventItem> wasItems,
) => Event(
  id: old.id,
  slug: old.slug,
  title: now.title,
  description: now.description,
  locationId: now.locationId,
  enemies: [
    for (final e in now.enemies)
      EventEnemy(
        id: was[e.characterId]?.id,
        characterId: e.characterId,
        amount: e.amount,
      ),
  ],
  items: [
    for (final id in now.itemIds) EventItem(id: wasItems[id]?.id, itemId: id),
  ],
);
