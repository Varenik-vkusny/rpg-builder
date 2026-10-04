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
  final will = {for (final e in now.enemies) e.characterId: e.amount};
  final wasItems = {for (final i in old.items) i.itemId: i};
  Map<String, dynamic> link(String? id, Map<String, dynamic> columns) => {
    'id': ?id,
    'project_id': worldId,
    ...columns,
  };
  return ManualEdit(
    title: 'Правка вручную: ${now.title}',
    slug: old.slug,
    ops: [
      if (row != null) rowOp('update', 'event', old.slug, row),
      for (final e in was.values)
        if (!will.containsKey(e.characterId))
          rowOp('delete', 'event_enemy', label(e.characterId), link(e.id, {}))
        else if (will[e.characterId] != e.amount)
          rowOp(
            'update',
            'event_enemy',
            label(e.characterId),
            link(e.id, {'amount': will[e.characterId]}),
          ),
      for (final e in now.enemies)
        if (!was.containsKey(e.characterId))
          rowOp(
            'create',
            'event_enemy',
            label(e.characterId),
            link(null, {'event_id': old.id, ...e.toJson()}),
          ),
      for (final i in wasItems.values)
        if (!now.itemIds.contains(i.itemId))
          rowOp('delete', 'event_item', label(i.itemId), link(i.id, {})),
      for (final id in now.itemIds)
        if (!wasItems.containsKey(id))
          rowOp(
            'create',
            'event_item',
            label(id),
            link(null, {'event_id': old.id, 'item_id': id}),
          ),
    ],
    applyTo: (w) => replaceObject(
      w,
      old.id,
      Event(
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
          for (final id in now.itemIds)
            EventItem(id: wasItems[id]?.id, itemId: id),
        ],
      ),
    ),
  );
}
