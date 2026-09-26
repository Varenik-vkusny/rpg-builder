// Экспорт мира в JSON под JsonUtility Unity (ideya.md §8): корень — объект, внутри только
// массивы и простые поля, ссылки через slug, schemaVersion. Словарей нет — JsonUtility их
// не читает. null тоже нет: у int в C# его не бывает, пустое — 0 или "".
import 'dart:convert';

import '../check/world_check.dart';
import '../content/slug.dart';
import '../worlds/world.dart';

/// Версия формата файла. Меняется, когда меняются поля.
const schemaVersion = 1;

/// Имя файла: «Пепельные копи» → `pepelnye_kopi.json`.
String exportFileName(World world) => '${slugify(world.title)}.json';

/// Мир → объект файла. Ссылки по id → slug; ссылка в никуда → "".
Map<String, Object> exportWorld(World world, WorldSnapshot w) {
  final slugs = {
    for (final l in w.locations) l.id: l.slug,
    for (final i in w.items) i.id: i.slug,
    for (final c in w.characters) c.id: c.slug,
    for (final q in w.quests) q.id: q.slug,
  };
  String ref(String? id) => slugs[id] ?? '';
  return {
    'schemaVersion': schemaVersion,
    'world': {
      'slug': slugify(world.title),
      'title': world.title,
      'setting': world.setting,
      'tone': world.tone,
      'levelMin': world.levelMin,
      'levelMax': world.levelMax,
    },
    'locations': [
      for (final l in w.locations)
        {
          'slug': l.slug,
          'name': l.title,
          'description': l.description,
          'levelMin': l.levelMin,
          'levelMax': l.levelMax,
        },
    ],
    'items': [
      for (final i in w.items)
        {
          'slug': i.slug,
          'name': i.title,
          'type': i.kind.name,
          'rarity': i.rarity.name,
          'level': i.level,
          'damage': i.damage ?? 0,
          'defense': i.defense ?? 0,
          'price': i.price,
          // Атрибуция образца (Open5e, CC BY 4.0); у своих предметов — "".
          'source': i.source ?? '',
          'sourceRef': i.sourceRef ?? '',
        },
    ],
    'characters': [
      for (final c in w.characters)
        {
          'slug': c.slug,
          'name': c.title,
          'description': c.description,
          'role': c.role.name,
          'level': c.level,
          'hp': c.hp,
          'attack': c.attack,
          'location': ref(c.locationId),
          'loot': [
            for (final l in c.loot) {'item': ref(l.itemId), 'chance': l.chance},
          ],
        },
    ],
    'quests': [
      for (final q in w.quests)
        {
          'slug': q.slug,
          'title': q.title,
          'description': q.description,
          'giver': ref(q.giverId),
          'steps': [
            for (final s in q.steps)
              {
                'kind': s.kind.name,
                'target': ref(s.targetId),
                'amount': s.amount ?? 1,
              },
          ],
          'rewards': [
            for (final r in q.rewardIds) {'item': ref(r), 'amount': 1},
          ],
        },
    ],
  };
}

/// Файл целиком — с отступами, чтобы автор мог прочитать его глазами.
String exportJson(World world, WorldSnapshot w) =>
    const JsonEncoder.withIndent('  ').convert(exportWorld(world, w));
