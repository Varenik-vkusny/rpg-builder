// Жест «из палитры в место» (5е): враг, житель, событие, предмет или место — одной
// строковой операцией «создать», как правка вручную. id новой строки даёт приложение:
// тогда копия мира для проверки и запись в базу говорят об одном и том же объекте.
import 'dart:math';

import '../check/world_check.dart';
import '../content/character.dart';
import '../content/event.dart';
import '../content/item.dart';
import '../content/location.dart';
import '../content/manual_edit.dart';
import '../content/slug.dart';

/// Что тащат из палитры.
enum NewKind { enemy, npc, event, item, place }

String newTitle(NewKind k) => switch (k) {
  NewKind.enemy => 'Новый враг',
  NewKind.npc => 'Новый житель',
  NewKind.event => 'Новое событие',
  NewKind.item => 'Новый предмет',
  NewKind.place => 'Новое место',
};

final _rnd = Random.secure();

/// uuid версии 4 — id новой строки.
String newId() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Новый объект жестом. [placeId] — место, куда бросили (у предмета — null: он на полке;
/// у места — родитель, null — верхний уровень). [levels] — уровни нового места.
({ManualEdit edit, String id}) createByGesture(
  String worldId,
  WorldSnapshot w,
  NewKind kind, {
  String? placeId,
  (int, int) levels = (1, 3),
}) {
  final id = newId();
  final title = newTitle(kind);
  Iterable<String> taken = switch (kind) {
    NewKind.enemy || NewKind.npc => w.characters.map((c) => c.slug),
    NewKind.event => w.events.map((e) => e.slug),
    NewKind.item => w.items.map((i) => i.slug),
    NewKind.place => w.locations.map((l) => l.slug),
  };
  final slug = uniqueSlug(title, taken);
  final base = {'id': id, 'project_id': worldId, 'slug': slug, 'title': title};
  final (type, row, add) = switch (kind) {
    NewKind.enemy || NewKind.npc => (
      'character',
      {
        ...base,
        'description': '',
        'role': kind == NewKind.enemy ? 'enemy' : 'npc',
        'location_id': placeId,
        'level': 1,
        'hp': 10,
        'attack': 0,
      },
      (WorldSnapshot s) => _with(
        s,
        characters: [
          ...s.characters,
          Character(
            id: id,
            slug: slug,
            title: title,
            description: '',
            role: kind == NewKind.enemy ? Role.enemy : Role.npc,
            locationId: placeId,
            loot: const [],
          ),
        ],
      ),
    ),
    NewKind.event => (
      'event',
      {...base, 'description': '', 'location_id': placeId},
      (WorldSnapshot s) => _with(
        s,
        events: [
          ...s.events,
          Event(
            id: id,
            slug: slug,
            title: title,
            description: '',
            locationId: placeId,
          ),
        ],
      ),
    ),
    NewKind.item => (
      'item',
      {...base, 'kind': 'misc', 'rarity': 'common', 'level': 1, 'price': 0},
      (WorldSnapshot s) => _with(
        s,
        items: [
          ...s.items,
          Item(
            id: id,
            slug: slug,
            title: title,
            kind: ItemKind.misc,
            rarity: Rarity.common,
            level: 1,
            damage: null,
            defense: null,
            price: 0,
          ),
        ],
      ),
    ),
    NewKind.place => (
      'location',
      {
        ...base,
        'description': '',
        'level_min': levels.$1,
        'level_max': levels.$2,
        'parent_id': placeId,
      },
      (WorldSnapshot s) => _with(
        s,
        locations: [
          ...s.locations,
          Location(
            id: id,
            slug: slug,
            title: title,
            description: '',
            levelMin: levels.$1,
            levelMax: levels.$2,
            parentId: placeId,
          ),
        ],
      ),
    ),
  };
  return (
    id: id,
    edit: ManualEdit(
      title: 'Холст: создано «$title»',
      slug: slug,
      ops: [rowOp('create', type, slug, row, slug: slug)],
      applyTo: add,
    ),
  );
}

WorldSnapshot _with(
  WorldSnapshot s, {
  List<Location>? locations,
  List<Item>? items,
  List<Character>? characters,
  List<Event>? events,
}) => WorldSnapshot(
  locations: locations ?? s.locations,
  items: items ?? s.items,
  characters: characters ?? s.characters,
  quests: s.quests,
  events: events ?? s.events,
);
