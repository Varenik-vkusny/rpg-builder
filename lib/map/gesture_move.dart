// Жест «перенос» (5е): объект (житель, враг, событие) — в другое место; место — внутрь
// другого места (дверь). Одна строковая операция «изменить», как правка вручную:
// проверка (место внутрь самого себя — ошибка, жест не применяется), история, откат.
import '../check/world_check.dart';
import '../content/character.dart';
import '../content/event.dart';
import '../content/location.dart';
import '../content/manual_edit.dart';

/// Перенос жителя, врага или события [id] в место [placeId].
ManualEdit moveObject(
  String worldId,
  WorldSnapshot w,
  String id,
  String placeId,
) {
  final to = w.locations.firstWhere((l) => l.id == placeId);
  final c = w.characters.where((x) => x.id == id).firstOrNull;
  if (c != null) {
    return ManualEdit(
      title: 'Холст: перенесено «${c.title}» → «${to.title}»',
      slug: c.slug,
      ops: [
        rowOp('update', 'character', c.slug, {
          'id': c.id,
          'project_id': worldId,
          'location_id': placeId,
        }),
      ],
      applyTo: (s) => replaceObject(
        s,
        id,
        Character(
          id: c.id,
          slug: c.slug,
          title: c.title,
          description: c.description,
          role: c.role,
          locationId: placeId,
          loot: c.loot,
          level: c.level,
          hp: c.hp,
          attack: c.attack,
          icon: c.icon,
          origin: c.origin,
        ),
      ),
    );
  }
  final e = w.events.firstWhere((x) => x.id == id);
  return ManualEdit(
    title: 'Холст: перенесено «${e.title}» → «${to.title}»',
    slug: e.slug,
    ops: [
      rowOp('update', 'event', e.slug, {
        'id': e.id,
        'project_id': worldId,
        'location_id': placeId,
      }),
    ],
    applyTo: (s) => replaceObject(
      s,
      id,
      Event(
        id: e.id,
        slug: e.slug,
        title: e.title,
        description: e.description,
        locationId: placeId,
        enemies: e.enemies,
        items: e.items,
      ),
    ),
  );
}

/// Место [id] — внутрь места [parentId] (null — на верхний уровень).
ManualEdit movePlace(
  String worldId,
  WorldSnapshot w,
  String id,
  String? parentId,
) {
  final l = w.locations.firstWhere((x) => x.id == id);
  final to = w.locations.where((x) => x.id == parentId).firstOrNull;
  return ManualEdit(
    title: 'Холст: «${l.title}» → внутрь «${to?.title ?? 'мира'}»',
    slug: l.slug,
    ops: [
      rowOp('update', 'location', l.slug, {
        'id': l.id,
        'project_id': worldId,
        'parent_id': parentId,
      }),
    ],
    applyTo: (s) => replaceObject(
      s,
      id,
      Location(
        id: l.id,
        slug: l.slug,
        title: l.title,
        description: l.description,
        levelMin: l.levelMin,
        levelMax: l.levelMax,
        parentId: parentId,
      ),
    ),
  );
}
