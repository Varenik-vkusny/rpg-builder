// Значок вида выбирает автор (5д): правка вручную одного поля icon — тем же путём,
// что любой жест (gesture_path.dart): проверка на копии, история, откат.
import '../check/world_check.dart';
import '../content/character.dart';
import '../content/item.dart';
import '../content/manual_edit.dart';
import 'glyphs.dart';

/// [icon] null — убрать значок (снова значок по роли или виду). Тот же значок — null.
ManualEdit? editIcon(String worldId, WorldSnapshot w, String id, String? icon) {
  final c = w.characters.where((x) => x.id == id).firstOrNull;
  final i = w.items.where((x) => x.id == id).firstOrNull;
  final (slug, title, type, was) = c != null
      ? (c.slug, c.title, 'character', c.icon)
      : (i!.slug, i.title, 'item', i.icon);
  final row = rowDiff(worldId, id, {'icon': was}, {'icon': icon});
  if (row == null) return null;
  final name = icon == null ? 'без значка' : glyphName(icon) ?? icon;
  return ManualEdit(
    title: 'Холст: значок «$title» — $name',
    slug: slug,
    ops: [rowOp('update', type, slug, row)],
    applyTo: (s) => replaceObject(
      s,
      id,
      c != null
          ? Character(
              id: c.id,
              slug: c.slug,
              title: c.title,
              description: c.description,
              role: c.role,
              locationId: c.locationId,
              loot: c.loot,
              level: c.level,
              hp: c.hp,
              attack: c.attack,
              icon: icon,
            )
          : Item(
              id: i!.id,
              slug: i.slug,
              title: i.title,
              kind: i.kind,
              rarity: i.rarity,
              level: i.level,
              damage: i.damage,
              defense: i.defense,
              price: i.price,
              source: i.source,
              sourceRef: i.sourceRef,
              icon: icon,
            ),
    ),
  );
}
