// План применяется к КОПИИ мира в памяти — база не трогается.
// Каждая операция даёт «было → стало» по полям или ошибку, почему её нельзя выполнить.
import '../check/world_check.dart';
import '../content/character.dart';
import '../content/event.dart';
import '../content/item.dart';
import '../content/location.dart';
import '../content/manual_edit.dart' show eventsOn, referencesWithoutEvents;
import '../content/quest.dart';
import 'plan.dart';
import 'plan_labels.dart';
import 'scope.dart';

part 'plan_apply_links.dart';

/// Одно изменённое поле: подпись, было, стало (null — значения нет).
class FieldChange {
  const FieldChange(this.label, this.before, this.after);
  final String label;
  final String? before;
  final String? after;
}

/// Итог одной операции на копии: заголовок, изменения полей или ошибка.
class OpResult {
  const OpResult(this.op, this.title, this.changes, [this.error]);
  final PlanOp op;
  final String title;
  final List<FieldChange> changes;
  final String? error;
}

final _slugFormat = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');

class _OpError implements Exception {
  const _OpError(this.message);
  final String message;
}

/// Применяет [plan] к копии [world]. Мир не меняется.
(WorldSnapshot, List<OpResult>) applyToCopy(WorldSnapshot world, Plan plan) {
  final c = _Copy(world);
  final results = [for (final op in plan.ops) c.apply(op)];
  return (c.snapshot, results);
}

class _Copy {
  _Copy(WorldSnapshot w)
    : locations = [...w.locations],
      items = [...w.items],
      characters = [...w.characters],
      quests = [...w.quests],
      events = w.events;

  final List<Location> locations;
  final List<Item> items;
  final List<Character> characters;
  final List<Quest> quests;

  /// События план не трогает (ассистент их не знает), но копия их помнит:
  /// по ним считаются ссылки и «предмет можно получить».
  final List<Event> events;

  WorldSnapshot get snapshot => WorldSnapshot(
    locations: locations,
    items: items,
    characters: characters,
    quests: quests,
    events: events,
  );

  late final labels = PlanLabels(() => snapshot);

  OpResult apply(PlanOp op) {
    final title = labels.opTitle(op);
    try {
      return OpResult(op, title, switch (op.type) {
        OpType.location => _location(op),
        OpType.item => _item(op),
        OpType.character => _character(op),
        OpType.quest => _quest(op),
        OpType.loot => _loot(op),
        OpType.questStep => _step(op),
        OpType.questReward => _reward(op),
      });
    } on _OpError catch (e) {
      return OpResult(op, title, const [], e.message);
    }
  }

  // ---------- поиск по slug ----------

  int _at<T>(
    List<T> list,
    String Function(T) slugOf,
    String? slug,
    String what,
  ) {
    final i = list.indexWhere((x) => slugOf(x) == slug);
    if (i < 0) throw _OpError('$what «$slug» нет в мире');
    return i;
  }

  String _idOf(String type, String slug) => switch (type) {
    'location' => locations[_at(locations, (x) => x.slug, slug, 'локации')].id,
    'item' => items[_at(items, (x) => x.slug, slug, 'предмета')].id,
    _ => characters[_at(characters, (x) => x.slug, slug, 'персонажа')].id,
  };

  /// Место объекта в списке: при создании — проверка нового slug и -1.
  int _slot<T>(
    PlanOp op,
    List<T> list,
    String Function(T) slugOf,
    String what,
  ) {
    if (op.action != OpAction.create) return _at(list, slugOf, op.slug, what);
    _newSlug(op.slug, list.map(slugOf));
    return -1;
  }

  /// Удалить можно, только если на объект уже ничего не ссылается — как в базе
  /// (внешние ключи): иначе копия пропустит план, который база отвергнет.
  /// Событие называется отдельно: эту строку читают и автор, и модель (проблема на исправление).
  void _removeUnreferenced<T>(List<T> list, int i, String id, String title) {
    final onEvents = [
      for (final e in eventsOn(snapshot, id))
        'на «$title» стоит событие «${e.title}»',
    ];
    final refs = referencesWithoutEvents(snapshot, id);
    if (onEvents.isNotEmpty || refs.isNotEmpty) {
      throw _OpError(
        [
          ...onEvents,
          if (refs.isNotEmpty)
            'на него ещё ссылаются (${refs.join('; ')}) — сначала убери ссылки',
        ].join('; '),
      );
    }
    list.removeAt(i);
  }

  void _newSlug(String? slug, Iterable<String> taken) {
    if (slug == null || !_slugFormat.hasMatch(slug)) {
      throw _OpError('slug «$slug» — только латиница, цифры и «_»');
    }
    if (taken.contains(slug)) throw _OpError('slug «$slug» уже занят');
  }

  T _need<T>(T? v, String what) => v ?? _missing(what);
  Never _missing(String what) => throw _OpError('не задано: $what');

  int _int(PlanOp op, String f, int old, {int min = 0}) {
    final v = op.integer(f) ?? old;
    if (v < min) throw _OpError('${fieldLabel(f)} — не меньше $min');
    return v;
  }

  List<FieldChange> _diff(Map<String, (Object?, Object?)> fields) => [
    for (final MapEntry(key: f, value: (b, a)) in fields.entries)
      if (b != a && !(b == null && a == ''))
        FieldChange(fieldLabel(f), labels.value(f, b), labels.value(f, a)),
  ];

  // ---------- объекты мира ----------

  List<FieldChange> _location(PlanOp op) {
    final i = _slot(op, locations, (x) => x.slug, 'локации');
    final old = i < 0 ? null : locations[i];
    if (op.action == OpAction.delete) {
      _removeUnreferenced(locations, i, old!.id, old.title);
      return const [];
    }
    final min = _int(
      op,
      'level_min',
      old?.levelMin ?? _need(op.integer('level_min'), 'уровни'),
      min: 1,
    );
    final max = _int(
      op,
      'level_max',
      old?.levelMax ?? _need(op.integer('level_max'), 'уровни'),
      min: 1,
    );
    if (min > max) throw const _OpError('уровни «от» больше «до»');
    // parent: slug места, «» — на верхний уровень, не задан — как было.
    final parent = op.str('parent');
    final l = Location(
      id: old?.id ?? 'new-location-${op.slug}',
      slug: op.slug!,
      title: op.str('title') ?? old?.title ?? _missing('название'),
      description: op.str('description') ?? old?.description ?? '',
      levelMin: min,
      levelMax: max,
      parentId: switch (parent) {
        null => old?.parentId,
        '' => null,
        _ => _idOf('location', parent),
      },
    );
    i < 0 ? locations.add(l) : locations[i] = l;
    return _diff({
      'title': (old?.title, l.title),
      'description': (old?.description, l.description),
      'level_min': (old?.levelMin, l.levelMin),
      'level_max': (old?.levelMax, l.levelMax),
      'parent': (old?.parentId, l.parentId),
    });
  }

  List<FieldChange> _item(PlanOp op) {
    final i = _slot(op, items, (x) => x.slug, 'предмета');
    final old = i < 0 ? null : items[i];
    if (op.action == OpAction.delete) {
      _removeUnreferenced(items, i, old!.id, old.title);
      return const [];
    }
    if (old != null &&
        op.str('kind') != null &&
        op.str('kind') != old.kind.name) {
      throw const _OpError('вид предмета не меняется');
    }
    final kind =
        old?.kind ?? ItemKind.values.byName(_need(op.str('kind'), 'вид'));
    final damage = kind == ItemKind.weapon
        ? _int(op, 'damage', old?.damage ?? _need(op.integer('damage'), 'урон'))
        : null;
    final defense = kind == ItemKind.armor
        ? _int(
            op,
            'defense',
            old?.defense ?? _need(op.integer('defense'), 'защита'),
          )
        : null;
    if (kind != ItemKind.weapon && op.integer('damage') != null) {
      throw const _OpError('урон бывает только у оружия');
    }
    if (kind != ItemKind.armor && op.integer('defense') != null) {
      throw const _OpError('защита бывает только у брони');
    }
    final it = Item(
      id: old?.id ?? 'new-item-${op.slug}',
      slug: op.slug!,
      title: op.str('title') ?? old?.title ?? _missing('название'),
      kind: kind,
      rarity: Rarity.values.byName(
        op.str('rarity') ?? old?.rarity.name ?? _missing('редкость'),
      ),
      level: _int(
        op,
        'level',
        old?.level ?? _need(op.integer('level'), 'уровень'),
        min: 1,
      ),
      damage: damage,
      defense: defense,
      price: _int(
        op,
        'price',
        old?.price ?? _need(op.integer('price'), 'цена'),
      ),
      // Источник задаётся только при создании (импорт) и дальше не меняется.
      source: old == null ? op.str('source') : old.source,
      sourceRef: old == null ? op.str('source_ref') : old.sourceRef,
    );
    i < 0 ? items.add(it) : items[i] = it;
    return _diff({
      'title': (old?.title, it.title),
      'kind': (old?.kind.name, it.kind.name),
      'rarity': (old?.rarity.name, it.rarity.name),
      'level': (old?.level, it.level),
      'damage': (old?.damage, it.damage),
      'defense': (old?.defense, it.defense),
      'price': (old?.price, it.price),
      'source': (old?.source, it.source),
      'source_ref': (old?.sourceRef, it.sourceRef),
    });
  }

  List<FieldChange> _character(PlanOp op) {
    final i = _slot(op, characters, (x) => x.slug, 'персонажа');
    final old = i < 0 ? null : characters[i];
    if (op.action == OpAction.delete) {
      _removeUnreferenced(characters, i, old!.id, old.title);
      return const [];
    }
    if (old != null &&
        op.str('role') != null &&
        op.str('role') != old.role.name) {
      throw const _OpError('роль персонажа не меняется');
    }
    final loc = op.str('location');
    final ch = Character(
      id: old?.id ?? 'new-character-${op.slug}',
      slug: op.slug!,
      title: op.str('title') ?? old?.title ?? _missing('имя'),
      description: op.str('description') ?? old?.description ?? '',
      role: old?.role ?? Role.values.byName(_need(op.str('role'), 'роль')),
      locationId: loc == null ? old?.locationId : _idOf('location', loc),
      loot: old?.loot ?? const [],
      level: _int(op, 'level', old?.level ?? 1, min: 1),
      hp: _int(op, 'hp', old?.hp ?? 10, min: 1),
      attack: _int(op, 'attack', old?.attack ?? 0),
    );
    i < 0 ? characters.add(ch) : characters[i] = ch;
    return _diff({
      'title': (old?.title, ch.title),
      'description': (old?.description, ch.description),
      'role': (old?.role.name, ch.role.name),
      'level': (old?.level, ch.level),
      'hp': (old?.hp, ch.hp),
      'attack': (old?.attack, ch.attack),
      'location': (old?.locationId, ch.locationId),
    });
  }

  List<FieldChange> _quest(PlanOp op) {
    final i = _slot(op, quests, (x) => x.slug, 'квеста');
    final old = i < 0 ? null : quests[i];
    if (op.action == OpAction.delete) {
      _removeUnreferenced(quests, i, old!.id, old.title);
      return const [];
    }
    final giver = op.str('giver');
    final q = _withQuest(
      old,
      id: old?.id ?? 'new-quest-${op.slug}',
      slug: op.slug!,
      title: op.str('title') ?? old?.title ?? _missing('название'),
      description: op.str('description') ?? old?.description ?? '',
      giverId: giver == null ? old?.giverId : _idOf('character', giver),
    );
    if (giver != null &&
        characters.firstWhere((c) => c.id == q.giverId).role != Role.npc) {
      throw const _OpError('квест выдаёт только житель');
    }
    i < 0 ? quests.add(q) : quests[i] = q;
    return _diff({
      'title': (old?.title, q.title),
      'description': (old?.description, q.description),
      'giver': (old?.giverId, q.giverId),
    });
  }

  Quest _withQuest(
    Quest? q, {
    String? id,
    String? slug,
    String? title,
    String? description,
    String? giverId,
    List<QuestStep>? steps,
    List<String>? rewardIds,
  }) => Quest(
    id: id ?? q!.id,
    slug: slug ?? q!.slug,
    title: title ?? q!.title,
    description: description ?? q!.description,
    giverId: giverId ?? q?.giverId,
    steps: steps ?? q?.steps ?? const [],
    rewardIds: rewardIds ?? q?.rewardIds ?? const [],
  );
}
