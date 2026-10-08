// Подменённая база в памяти для тестов экранов: авторы, миры, содержимое.
import 'dart:async';

import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/assistant/history.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/auth/auth_service.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/content/quest.dart';
import 'package:rpg_builder/content/slug.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';

import 'fakes_journal.dart';

class FakeAuth implements AuthService {
  final _changes = StreamController<bool>.broadcast();
  String? user;

  @override
  Stream<bool> get signedInChanges => _changes.stream;
  @override
  bool get isSignedIn => user != null;

  @override
  Future<void> signIn(String email, String password) async {
    user = email;
    _changes.add(true);
  }

  @override
  Future<void> signUp(String email, String password) => signIn(email, password);

  @override
  Future<void> signOut() async {
    user = null;
    _changes.add(false);
  }
}

/// Хранит миры по владельцу — как это делает RLS в базе.
class FakeWorlds implements WorldsRepo {
  FakeWorlds(this.auth);
  final FakeAuth auth;
  final _byOwner = <String, List<World>>{};

  @override
  Future<List<World>> listMine() async =>
      List.of(_byOwner[auth.user] ?? const []);

  @override
  Future<World> create(NewWorld w) async {
    final world = World(
      id: '${_byOwner.length}-${w.title}',
      title: w.title,
      setting: w.setting,
      tone: w.tone,
      levelMin: w.levelMin,
      levelMax: w.levelMax,
    );
    _byOwner.putIfAbsent(auth.user!, () => []).add(world);
    return world;
  }
}

/// Содержимое по мирам. Миры у авторов разные, так что изоляция — через FakeWorlds.
class FakeContent implements ContentRepo {
  final _locations = <String, List<Location>>{};

  @override
  Future<List<Location>> locations(String worldId) async =>
      List.of(_locations[worldId] ?? const []);

  @override
  Future<Location> createLocation(String worldId, NewLocation l) async {
    final list = _locations.putIfAbsent(worldId, () => []);
    final loc = Location(
      id: 'loc-${list.length}',
      slug: uniqueSlug(l.title, list.map((x) => x.slug)),
      title: l.title,
      description: l.description,
      levelMin: l.levelMin,
      levelMax: l.levelMax,
      parentId: l.parentId,
    );
    list.add(loc);
    return loc;
  }

  final _items = <String, List<Item>>{};

  @override
  Future<List<Item>> items(String worldId) async =>
      List.of(_items[worldId] ?? const []);

  @override
  Future<Item> createItem(String worldId, NewItem i) async {
    final list = _items.putIfAbsent(worldId, () => []);
    final row = i.toRow(worldId, uniqueSlug(i.title, list.map((x) => x.slug)));
    final item = Item.fromRow({...row, 'id': 'item-${list.length}'});
    list.add(item);
    return item;
  }

  final _characters = <String, List<Character>>{};

  @override
  Future<List<Character>> characters(String worldId) async =>
      List.of(_characters[worldId] ?? const []);

  @override
  Future<Character> createCharacter(String worldId, NewCharacter c) async {
    final list = _characters.putIfAbsent(worldId, () => []);
    final p = c.toParams(worldId, uniqueSlug(c.title, list.map((x) => x.slug)));
    final character = Character.fromRow({
      'id': 'char-${list.length}',
      'slug': p['p_slug'],
      'title': p['p_title'],
      'description': p['p_description'],
      'role': p['p_role'],
      'location_id': p['p_location_id'],
      'level': p['p_level'],
      'hp': p['p_hp'],
      'attack': p['p_attack'],
      'loot': p['p_loot'],
    });
    list.add(character);
    return character;
  }

  final _quests = <String, List<Quest>>{};

  @override
  Future<List<Quest>> quests(String worldId) async =>
      List.of(_quests[worldId] ?? const []);

  @override
  Future<Quest> createQuest(String worldId, NewQuest q) async {
    final list = _quests.putIfAbsent(worldId, () => []);
    final p = q.toParams(worldId, uniqueSlug(q.title, list.map((x) => x.slug)));
    // Через те же строки, что шлёт и читает настоящая база.
    final quest = Quest.fromRow({
      'id': 'quest-${list.length}',
      'slug': p['p_slug'],
      'title': p['p_title'],
      'description': p['p_description'],
      'giver_id': p['p_giver_id'],
      'quest_steps': [
        for (final (i, s) in (p['p_steps'] as List).indexed)
          {...s as Map<String, dynamic>, 'position': i + 1},
      ],
      'quest_rewards': [
        for (final id in p['p_rewards'] as List) {'item_id': id},
      ],
    });
    list.add(quest);
    return quest;
  }

  final _events = <String, List<Event>>{};

  @override
  Future<List<Event>> events(String worldId) async =>
      List.of(_events[worldId] ?? const []);

  @override
  Future<Event> createEvent(String worldId, NewEvent e) async {
    final list = _events.putIfAbsent(worldId, () => []);
    final p = e.toParams(worldId, uniqueSlug(e.title, list.map((x) => x.slug)));
    final n = list.length;
    // Через те же строки, что шлёт и читает настоящая база: у связей свои id.
    final event = Event.fromRow({
      'id': 'event-$n',
      'slug': p['p_slug'],
      'title': p['p_title'],
      'description': p['p_description'],
      'location_id': p['p_location_id'],
      'event_enemies': [
        for (final (i, x) in (p['p_enemies'] as List).indexed)
          {...x as Map<String, dynamic>, 'id': 'event-$n-enemy-$i'},
      ],
      'event_items': [
        for (final (i, id) in (p['p_items'] as List).indexed)
          {'id': 'event-$n-item-$i', 'item_id': id},
      ],
    });
    list.add(event);
    return event;
  }

  final changeSets = <FakeChangeSet>[];

  /// Журнал наборов: мир до и после набора. Откат возвращает «до», если мир
  /// с тех пор не трогали; иначе — конфликт (грубее базы: по миру целиком).
  final journal = <FakeJournalSet>[];

  /// Растёт на каждой записи в мир — так подменённая база видит «меняли после набора».
  int version = 0;

  /// Как база: план на мир целиком, любая невыполнимая операция — ничего не пишется.
  @override
  Future<void> applyChangeSet(String worldId, ChangeSetDraft draft) async {
    final before = await snapshotOf(worldId);
    final (copy, results) = applyToCopy(before, draft.plan);
    final failed = results.where((r) => r.error != null);
    if (failed.isNotEmpty) throw StateError(failed.first.error!);
    _restore(worldId, copy);
    changeSets.add((status: 'applied', draft: draft));
    _log(worldId, SetStatus.applied, draft.request, draft.plan.summary, [
      for (final r in results)
        JournalOp(
          action: r.op.action.name,
          type: r.op.typeName,
          label: _label(r.op),
          before: {for (final c in r.changes) c.label: c.before},
          after: {for (final c in r.changes) c.label: c.after},
        ),
    ], before);
  }

  @override
  Future<void> rejectChangeSet(String worldId, ChangeSetDraft draft) async {
    changeSets.add((status: 'rejected', draft: draft));
    _log(worldId, SetStatus.rejected, draft.request, draft.plan.summary, [
      for (final op in draft.plan.ops)
        JournalOp(action: op.action.name, type: op.typeName, label: _label(op)),
    ], null);
  }

  void _restore(String worldId, WorldSnapshot w) {
    _locations[worldId] = [...w.locations];
    _items[worldId] = [...w.items];
    _characters[worldId] = [...w.characters];
    _quests[worldId] = [...w.quests];
    _events[worldId] = [...w.events];
    version++;
  }

  /// Подпись операции, как в базе: slug, «враг/предмет», «квест#шаг».
  static String _label(PlanOp op) => switch (op.type) {
    OpType.loot => '${op.character}/${op.item}',
    OpType.questReward => '${op.quest}/${op.item}',
    OpType.questStep => '${op.quest}#${op.position}',
    _ => op.slug ?? '',
  };

  void _log(
    String worldId,
    SetStatus status,
    String request,
    String summary,
    List<JournalOp> ops,
    WorldSnapshot? before, {
    String? revertsId,
  }) => journal.add(
    FakeJournalSet(
      worldId: worldId,
      entry: ChangeSetEntry(
        id: 'set-${journal.length}',
        status: status,
        request: request,
        summary: summary,
        createdAt: DateTime(2026, 9, 24, 12, journal.length),
        revertsId: revertsId,
        ops: ops,
      ),
      before: before,
      version: version,
    ),
  );

  /// Как база: на удаляемый объект ссылаются — отказ; иначе мир после правки.
  @override
  Future<void> applyManualEdit(String worldId, ManualEdit edit) async {
    final before = await snapshotOf(worldId);
    for (final op in edit.ops) {
      final id = (op['row'] as Map)['id'] as String?;
      if (op['action'] == 'delete' && id != null) {
        final refs = referencesTo(before, id);
        if (refs.isNotEmpty) throw StateError('на объект ссылаются: $refs');
      }
    }
    _restore(worldId, edit.applyTo(before));
    _log(worldId, SetStatus.applied, edit.title, edit.title, [
      for (final op in edit.ops)
        JournalOp(
          action: op['action'] as String,
          type: op['type'] as String,
          label: op['label'] as String,
        ),
    ], before);
  }

  /// Раскладка карты по мирам: id места → положение. Мимо истории, как в базе.
  final _layout = <String, Map<String, Spot>>{};

  /// Сколько раз автор перетаскивал блоки — тестам видно, что перенос сохранён.
  int moves = 0;

  @override
  Future<Map<String, Spot>> layout(String worldId) async =>
      Map.of(_layout[worldId] ?? const {});

  @override
  Future<void> moveLocation(
    String worldId,
    String locationId,
    Spot spot,
  ) async {
    moves++;
    _layout.putIfAbsent(worldId, () => {})[locationId] = spot;
  }

  @override
  Future<List<ChangeSetEntry>> history(String worldId) async => [
    for (final s in journal.reversed)
      if (s.worldId == worldId) s.entry,
  ];

  @override
  Future<List<RevertConflict>> revertConflicts(
    String worldId,
    String setId,
  ) async {
    final s = journal.firstWhere((s) => s.entry.id == setId);
    return s.version == version
        ? []
        : [const RevertConflict('world', 'мир', 'изменён после набора')];
  }

  @override
  Future<void> revertChangeSet(String worldId, String setId) async {
    final i = journal.indexWhere((s) => s.entry.id == setId);
    final s = journal[i];
    if (!s.entry.canRevert) {
      throw StateError('откатить можно только применённый');
    }
    if ((await revertConflicts(worldId, setId)).isNotEmpty) {
      throw StateError('конфликт отката');
    }
    final now = await snapshotOf(worldId);
    _restore(worldId, s.before!);
    journal[i] = s.reverted();
    _log(
      worldId,
      SetStatus.applied,
      s.entry.request,
      'Откат: ${s.entry.summary}',
      [
        for (final op in s.entry.ops.reversed)
          JournalOp(
            action: switch (op.action) {
              'create' => 'delete',
              'delete' => 'create',
              _ => 'update',
            },
            type: op.type,
            label: op.label,
            before: op.after,
            after: op.before,
          ),
      ],
      now,
      revertsId: setId,
    );
  }

  Future<WorldSnapshot> snapshotOf(String worldId) async => WorldSnapshot(
    locations: await locations(worldId),
    items: await items(worldId),
    characters: await characters(worldId),
    quests: await quests(worldId),
    events: await events(worldId),
  );
}
