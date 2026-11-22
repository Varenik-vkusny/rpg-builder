// Создание объекта формой (правило 11, найдено на телефоне 22.11): тем же набором
// изменений, что жест и правка вручную, — проверка на копии, набор в истории, откат.
// Раньше форма писала в базу напрямую: созданного формой в истории не было.
import '../check/world_check.dart';
import 'character.dart';
import 'event.dart';
import 'item.dart';
import 'location.dart';
import 'manual_edit.dart';
import 'new_id.dart';
import 'quest.dart';
import 'slug.dart';

/// Подпись набора в истории — рядом с «Правка вручную» и «Удаление вручную».
String _title(String title) => 'Создано вручную: $title';

Map<String, dynamic> _base(String worldId, String id, String slug, String t) =>
    {'id': id, 'project_id': worldId, 'slug': slug, 'title': t};

WorldSnapshot _with(
  WorldSnapshot s, {
  Location? location,
  Item? item,
  Character? character,
  Quest? quest,
  Event? event,
}) => WorldSnapshot(
  locations: [...s.locations, ?location],
  items: [...s.items, ?item],
  characters: [...s.characters, ?character],
  quests: [...s.quests, ?quest],
  events: [...s.events, ?event],
);

ManualEdit createLocationEdit(
  String worldId,
  WorldSnapshot w,
  NewLocation now,
) {
  final id = newId();
  final slug = uniqueSlug(now.title, w.locations.map((l) => l.slug));
  return ManualEdit(
    title: _title(now.title),
    slug: slug,
    ops: [
      rowOp('create', 'location', slug, {
        ..._base(worldId, id, slug, now.title),
        'description': now.description,
        'level_min': now.levelMin,
        'level_max': now.levelMax,
        'parent_id': now.parentId,
      }, slug: slug),
    ],
    applyTo: (s) => _with(
      s,
      location: Location(
        id: id,
        slug: slug,
        title: now.title,
        description: now.description,
        levelMin: now.levelMin,
        levelMax: now.levelMax,
        parentId: now.parentId,
      ),
    ),
  );
}

ManualEdit createItemEdit(String worldId, WorldSnapshot w, NewItem now) {
  final id = newId();
  final slug = uniqueSlug(now.title, w.items.map((i) => i.slug));
  return ManualEdit(
    title: _title(now.title),
    slug: slug,
    ops: [
      rowOp('create', 'item', slug, {
        ..._base(worldId, id, slug, now.title),
        'kind': now.kind.name,
        'rarity': now.rarity.name,
        'level': now.level,
        'damage': now.damage,
        'defense': now.defense,
        'price': now.price,
      }, slug: slug),
    ],
    applyTo: (s) => _with(
      s,
      item: Item(
        id: id,
        slug: slug,
        title: now.title,
        kind: now.kind,
        rarity: now.rarity,
        level: now.level,
        damage: now.damage,
        defense: now.defense,
        price: now.price,
      ),
    ),
  );
}

/// Персонаж и его добыча — одним набором: сначала персонаж, потом строки добычи.
ManualEdit createCharacterEdit(
  String worldId,
  WorldSnapshot w,
  NewCharacter now,
) {
  final id = newId();
  final slug = uniqueSlug(now.title, w.characters.map((c) => c.slug));
  final itemSlugs = {for (final i in w.items) i.id: i.slug};
  final loot = now.role == Role.enemy ? now.loot : const <LootDrop>[];
  return ManualEdit(
    title: _title(now.title),
    slug: slug,
    ops: [
      rowOp('create', 'character', slug, {
        ..._base(worldId, id, slug, now.title),
        'description': now.description,
        'role': now.role.name,
        'location_id': now.locationId,
        'level': now.level,
        'hp': now.hp,
        'attack': now.attack,
      }, slug: slug),
      for (final l in loot)
        rowOp('create', 'loot', '$slug/${itemSlugs[l.itemId] ?? l.itemId}', {
          'project_id': worldId,
          'character_id': id,
          'item_id': l.itemId,
          'chance': l.chance,
        }),
    ],
    applyTo: (s) => _with(
      s,
      character: Character(
        id: id,
        slug: slug,
        title: now.title,
        description: now.description,
        role: now.role,
        locationId: now.locationId,
        loot: loot,
        level: now.level,
        hp: now.hp,
        attack: now.attack,
      ),
    ),
  );
}

/// Квест, его шаги по порядку и награды — одним набором.
ManualEdit createQuestEdit(String worldId, WorldSnapshot w, NewQuest now) {
  final id = newId();
  final slug = uniqueSlug(now.title, w.quests.map((q) => q.slug));
  Map<String, dynamic> step(int position, QuestStep s) => {
    'project_id': worldId,
    'quest_id': id,
    'position': position,
    'kind': s.kind.name,
    'character_id': s.kind == StepKind.talk || s.kind == StepKind.kill
        ? s.targetId
        : null,
    'item_id': s.kind == StepKind.collect ? s.targetId : null,
    'location_id': s.kind == StepKind.visit ? s.targetId : null,
    'event_id': s.kind == StepKind.event ? s.targetId : null,
    'amount': s.kind.counted ? s.amount : null,
  };
  return ManualEdit(
    title: _title(now.title),
    slug: slug,
    ops: [
      rowOp('create', 'quest', slug, {
        ..._base(worldId, id, slug, now.title),
        'description': now.description,
        'giver_id': now.giverId,
      }, slug: slug),
      for (final (i, s) in now.steps.indexed)
        rowOp('create', 'quest_step', '$slug#${i + 1}', step(i + 1, s)),
      for (final r in now.rewardIds)
        rowOp('create', 'quest_reward', '$slug/$r', {
          'project_id': worldId,
          'quest_id': id,
          'item_id': r,
        }),
    ],
    applyTo: (s) => _with(
      s,
      quest: Quest(
        id: id,
        slug: slug,
        title: now.title,
        description: now.description,
        giverId: now.giverId,
        steps: now.steps,
        rewardIds: now.rewardIds,
      ),
    ),
  );
}

/// Событие, его враги и предметы — одним набором.
ManualEdit createEventEdit(String worldId, WorldSnapshot w, NewEvent now) {
  final id = newId();
  final slug = uniqueSlug(now.title, w.events.map((e) => e.slug));
  final slugs = {
    for (final c in w.characters) c.id: c.slug,
    for (final i in w.items) i.id: i.slug,
  };
  String label(String of) => '$slug/${slugs[of] ?? of}';
  return ManualEdit(
    title: _title(now.title),
    slug: slug,
    ops: [
      rowOp('create', 'event', slug, {
        ..._base(worldId, id, slug, now.title),
        'description': now.description,
        'location_id': now.locationId,
      }, slug: slug),
      for (final e in now.enemies)
        rowOp('create', 'event_enemy', label(e.characterId), {
          'project_id': worldId,
          'event_id': id,
          ...e.toJson(),
        }),
      for (final i in now.itemIds)
        rowOp('create', 'event_item', label(i), {
          'project_id': worldId,
          'event_id': id,
          'item_id': i,
        }),
    ],
    applyTo: (s) => _with(
      s,
      event: Event(
        id: id,
        slug: slug,
        title: now.title,
        description: now.description,
        locationId: now.locationId,
        enemies: now.enemies,
        items: [for (final i in now.itemIds) EventItem(itemId: i)],
      ),
    ),
  );
}
