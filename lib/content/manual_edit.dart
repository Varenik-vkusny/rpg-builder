// Ручная правка и удаление объектов (4.1) — набором изменений через ту же запись,
// что «Применить» и откат: правка попадает в историю, её можно откатить, а откат
// старого набора увидит, что объект меняли руками (конфликт).
//
// Операции «строковые», как у отката: {action, type, row, label, slug}. row — только
// меняемые столбцы + id и мир; пустое поле (убрать локацию) передаётся как null.
import '../check/world_check.dart';
import 'character.dart';
import 'item.dart';
import 'location.dart';
import 'quest.dart';

/// Правка вручную: что меняем и какие строки пишем.
class ManualEdit {
  const ManualEdit({
    required this.title,
    required this.slug,
    required this.ops,
    required this.applyTo,
  });

  /// «Правка вручную: Слизень» — так набор подписан в истории.
  final String title;
  final String slug;
  final List<Map<String, dynamic>> ops;

  /// Мир после правки — в памяти: его проверяют те же правила (правило 4).
  final WorldSnapshot Function(WorldSnapshot) applyTo;

  bool get isEmpty => ops.isEmpty;
}

/// Мир, где объект с [id] заменён на [next] (null — удалён).
WorldSnapshot _replace(WorldSnapshot w, String id, Object? next) {
  List<T> swap<T>(List<T> list, String Function(T) idOf) => [
    for (final x in list)
      if (idOf(x) != id) x else if (next is T) next,
  ];
  return WorldSnapshot(
    locations: swap(w.locations, (x) => x.id),
    items: swap(w.items, (x) => x.id),
    characters: swap(w.characters, (x) => x.id),
    quests: swap(w.quests, (x) => x.id),
  );
}

Map<String, dynamic> _op(
  String action,
  String type,
  String label,
  Map<String, dynamic> row, {
  String? slug,
}) => {
  'action': action,
  'type': type,
  'label': label,
  'row': row,
  'slug': ?slug,
};

/// Только изменившиеся столбцы; ничего не поменяли — null.
Map<String, dynamic>? _diff(
  String worldId,
  String id,
  Map<String, Object?> was,
  Map<String, Object?> now,
) {
  final changed = {
    for (final k in now.keys)
      if (was[k] != now[k]) k: now[k],
  };
  if (changed.isEmpty) return null;
  return {'id': id, 'project_id': worldId, ...changed};
}

ManualEdit editLocation(String worldId, Location old, NewLocation now) {
  final row = _diff(
    worldId,
    old.id,
    {
      'title': old.title,
      'description': old.description,
      'level_min': old.levelMin,
      'level_max': old.levelMax,
    },
    {
      'title': now.title,
      'description': now.description,
      'level_min': now.levelMin,
      'level_max': now.levelMax,
    },
  );
  return ManualEdit(
    title: 'Правка вручную: ${now.title}',
    slug: old.slug,
    ops: [if (row != null) _op('update', 'location', old.slug, row)],
    applyTo: (w) => _replace(
      w,
      old.id,
      Location(
        id: old.id,
        slug: old.slug,
        title: now.title,
        description: now.description,
        levelMin: now.levelMin,
        levelMax: now.levelMax,
      ),
    ),
  );
}

/// Вид предмета не меняется (как и в плане): урон и защита держатся на нём.
ManualEdit editItem(String worldId, Item old, NewItem now) {
  final row = _diff(
    worldId,
    old.id,
    {
      'title': old.title,
      'rarity': old.rarity.name,
      'level': old.level,
      'damage': old.damage,
      'defense': old.defense,
      'price': old.price,
    },
    {
      'title': now.title,
      'rarity': now.rarity.name,
      'level': now.level,
      'damage': now.damage,
      'defense': now.defense,
      'price': now.price,
    },
  );
  return ManualEdit(
    title: 'Правка вручную: ${now.title}',
    slug: old.slug,
    ops: [if (row != null) _op('update', 'item', old.slug, row)],
    applyTo: (w) => _replace(
      w,
      old.id,
      Item(
        id: old.id,
        slug: old.slug,
        title: now.title,
        kind: old.kind,
        rarity: now.rarity,
        level: now.level,
        damage: now.damage,
        defense: now.defense,
        price: now.price,
        source: old.source,
        sourceRef: old.sourceRef,
      ),
    ),
  );
}

/// Роль не меняется (как и в плане). Добыча — по разнице: убрать, поменять шанс, добавить.
ManualEdit editCharacter(
  String worldId,
  Character old,
  NewCharacter now,
  Map<String, String> itemSlugs,
) {
  final row = _diff(
    worldId,
    old.id,
    {
      'title': old.title,
      'description': old.description,
      'location_id': old.locationId,
      'level': old.level,
      'hp': old.hp,
      'attack': old.attack,
    },
    {
      'title': now.title,
      'description': now.description,
      'location_id': now.locationId,
      'level': now.level,
      'hp': now.hp,
      'attack': now.attack,
    },
  );
  final was = {for (final l in old.loot) l.itemId: l.chance};
  final will = {for (final l in now.loot) l.itemId: l.chance};
  String label(String itemId) => '${old.slug}/${itemSlugs[itemId] ?? itemId}';
  Map<String, dynamic> lootRow(String itemId, [double? chance]) => {
    'project_id': worldId,
    'character_id': old.id,
    'item_id': itemId,
    'chance': ?chance,
  };
  return ManualEdit(
    title: 'Правка вручную: ${now.title}',
    slug: old.slug,
    ops: [
      if (row != null) _op('update', 'character', old.slug, row),
      for (final id in was.keys)
        if (!will.containsKey(id))
          _op('delete', 'loot', label(id), lootRow(id))
        else if (will[id] != was[id])
          _op('update', 'loot', label(id), lootRow(id, will[id])),
      for (final id in will.keys)
        if (!was.containsKey(id))
          _op('create', 'loot', label(id), lootRow(id, will[id])),
    ],
    applyTo: (w) => _replace(
      w,
      old.id,
      Character(
        id: old.id,
        slug: old.slug,
        title: now.title,
        description: now.description,
        role: old.role,
        locationId: now.locationId,
        loot: old.role == Role.enemy ? now.loot : const [],
        level: now.level,
        hp: now.hp,
        attack: now.attack,
      ),
    ),
  );
}

/// Шаги поменялись — старые убираются с последнего, новые пишутся по порядку.
/// Награды — по разнице.
ManualEdit editQuest(String worldId, Quest old, NewQuest now) {
  final row = _diff(
    worldId,
    old.id,
    {
      'title': old.title,
      'description': old.description,
      'giver_id': old.giverId,
    },
    {
      'title': now.title,
      'description': now.description,
      'giver_id': now.giverId,
    },
  );
  String sig(List<QuestStep> s) =>
      s.map((x) => '${x.kind.name}:${x.targetId}:${x.amount}').join('|');
  final stepsChanged = sig(old.steps) != sig(now.steps);
  Map<String, dynamic> stepRow(int position, [QuestStep? s]) => {
    'project_id': worldId,
    'quest_id': old.id,
    'position': position,
    if (s != null) ...{
      'kind': s.kind.name,
      'character_id': s.kind == StepKind.talk || s.kind == StepKind.kill
          ? s.targetId
          : null,
      'item_id': s.kind == StepKind.collect ? s.targetId : null,
      'location_id': s.kind == StepKind.visit ? s.targetId : null,
      'amount': s.kind.counted ? s.amount : null,
    },
  };
  Map<String, dynamic> rewardRow(String itemId) => {
    'project_id': worldId,
    'quest_id': old.id,
    'item_id': itemId,
  };
  return ManualEdit(
    title: 'Правка вручную: ${now.title}',
    slug: old.slug,
    ops: [
      if (row != null) _op('update', 'quest', old.slug, row),
      if (stepsChanged) ...[
        for (var p = old.steps.length; p >= 1; p--)
          _op('delete', 'quest_step', '${old.slug}#$p', stepRow(p)),
        for (final (i, s) in now.steps.indexed)
          _op(
            'create',
            'quest_step',
            '${old.slug}#${i + 1}',
            stepRow(i + 1, s),
          ),
      ],
      for (final id in old.rewardIds)
        if (!now.rewardIds.contains(id))
          _op('delete', 'quest_reward', '${old.slug}/$id', rewardRow(id)),
      for (final id in now.rewardIds)
        if (!old.rewardIds.contains(id))
          _op('create', 'quest_reward', '${old.slug}/$id', rewardRow(id)),
    ],
    applyTo: (w) => _replace(
      w,
      old.id,
      Quest(
        id: old.id,
        slug: old.slug,
        title: now.title,
        description: now.description,
        giverId: now.giverId,
        steps: now.steps,
        rewardIds: now.rewardIds,
      ),
    ),
  );
}

/// Кто ссылается на объект [id] — словами. Непусто — удалять нельзя.
/// Своя добыча врага и свои шаги квеста — не ссылки: уходят вместе с ним.
List<String> referencesTo(WorldSnapshot w, String id) => [
  for (final c in w.characters) ...[
    if (c.locationId == id) 'живёт здесь: «${c.title}»',
    if (c.loot.any((l) => l.itemId == id)) 'роняет: «${c.title}»',
  ],
  for (final q in w.quests) ...[
    if (q.giverId == id) 'выдаёт квест «${q.title}»',
    for (final (i, s) in q.steps.indexed)
      if (s.targetId == id) 'шаг ${i + 1} квеста «${q.title}»',
    if (q.rewardIds.contains(id)) 'награда за квест «${q.title}»',
  ],
];

/// Удаление объекта одной операцией. Добыча врага, шаги и награды квеста уходят
/// вместе с ним — база сама пишет их в журнал (откат вернёт).
ManualEdit deleteObject(
  String worldId, {
  required String type,
  required String id,
  required String slug,
  required String title,
}) => ManualEdit(
  title: 'Удаление вручную: $title',
  slug: slug,
  ops: [
    _op('delete', type, slug, {'id': id, 'project_id': worldId}, slug: slug),
  ],
  applyTo: (w) => _replace(w, id, null),
);
