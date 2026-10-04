// Событие в НАСТОЯЩЕЙ базе (5б.1): создаётся одной транзакцией с врагами и предметами;
// чужой автор его не видит; место, врага и предмет под событием база удалить не даёт;
// правка и удаление — набором в историю, откат возвращает событие целиком.
// Шаг квеста «пройти событие» — test/event_step_db_test.dart.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/event_edit.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'db_helpers.dart';

void main() {
  late SupabaseClient a;
  late SupabaseClient b;
  late World world;
  late SupabaseContentRepo repo;
  late Event ambush;

  setUpAll(() async {
    (a, b) = await twoAuthors();
    repo = SupabaseContentRepo(a);
  });

  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Событие ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    await fillMines(repo, world.id);
    ambush = await addAmbush(repo, world.id);
  });

  tearDown(() => a.from('projects').delete().eq('id', world.id));

  Future<WorldSnapshot> w() => repo.snapshot(world.id);
  Future<void> revertLast() async =>
      repo.revertChangeSet(world.id, (await repo.history(world.id)).first.id);

  /// Событие словами: «название @ место | враг × N | предмет».
  String show(WorldSnapshot s) => [
    for (final e in s.events)
      [
        '${e.title} @ ${s.titles[e.locationId]}',
        for (final x in e.enemies) '${s.titles[x.characterId]} × ${x.amount}',
        for (final id in e.itemIds) s.titles[id],
      ].join(' | '),
  ].join('\n');

  String id(WorldSnapshot s, String slug) => [
    ...s.locations.map((x) => (x.slug, x.id)),
    ...s.items.map((x) => (x.slug, x.id)),
    ...s.characters.map((x) => (x.slug, x.id)),
  ].firstWhere((x) => x.$1 == slug).$2;

  test('событие создаётся с врагами и предметами; чужой автор его не видит; '
      'slug не меняется', () async {
    expect(ambush.slug, 'zasada_u_lebedki');
    expect(show(await w()), 'Засада у лебёдки @ Штольня №3 | Слизень × 3 | Ключ');
    // У связей свои id — по ним идут правка и откат.
    expect(ambush.enemies.single.id, isNotNull);
    expect(ambush.items.single.id, isNotNull);

    for (final table in ['events', 'event_enemies', 'event_items']) {
      expect(
        await b.from(table).select().eq('project_id', world.id),
        isEmpty,
        reason: 'чужой автор видит $table',
      );
    }
    await expectLater(
      SupabaseContentRepo(b).createEvent(
        world.id,
        NewEvent(
          title: 'Чужое',
          description: '',
          locationId: ambush.locationId!,
        ),
      ),
      throwsA(isA<PostgrestException>()),
    );
    await expectSlugLocked(a, 'events', ambush.id, 'zasada_u_lebedki');
  });

  test('база не пускает: событие без места, не-врага в событие, число 0, '
      'объекты чужого мира', () async {
    final s = await w();
    Future<void> refused(String what, Map<String, dynamic> params) =>
        expectLater(
          a.rpc('create_event', params: params),
          throwsA(isA<PostgrestException>()),
          reason: what,
        );
    Map<String, dynamic> params({
      String? locationId,
      List<Map<String, dynamic>> enemies = const [],
      List<String> items = const [],
    }) => {
      'p_project_id': world.id,
      'p_slug': 'proba',
      'p_title': 'Проба',
      'p_description': '',
      'p_location_id': locationId,
      'p_enemies': enemies,
      'p_items': items,
    };
    final shaft = id(s, 'shtolnya_3');
    await refused('без места', params());
    await refused(
      'житель вместо врага',
      params(
        locationId: shaft,
        enemies: [
          {'character_id': id(s, 'brigadir'), 'amount': 1},
        ],
      ),
    );
    await refused(
      'число 0',
      params(
        locationId: shaft,
        enemies: [
          {'character_id': id(s, 'slizen'), 'amount': 0},
        ],
      ),
    );
    // Второй мир того же автора: его место в событие этого мира не годится.
    final other = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Другой ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    addTearDown(() => a.from('projects').delete().eq('id', other.id));
    await fillMines(repo, other.id);
    final foreign = id(await repo.snapshot(other.id), 'shtolnya_3');
    await refused('место чужого мира', params(locationId: foreign));
    // Отказ — целиком: ни события, ни связей от неудачных попыток.
    expect((await w()).events, hasLength(1));
  });

  test('место, врага и предмет под событием база удалить не даёт', () async {
    final s = await w();
    // Ссылки квеста и добычи убраны: держит только событие.
    await a.from('quests').delete().eq('project_id', world.id);
    await a.from('loot').delete().eq('project_id', world.id);
    await a
        .from('characters')
        .update({'location_id': null})
        .eq('project_id', world.id);
    for (final (table, slug) in [
      ('locations', 'shtolnya_3'),
      ('characters', 'slizen'),
      ('items', 'klyuch'),
    ]) {
      await expectLater(
        a.from(table).delete().eq('id', id(s, slug)).select(),
        throwsA(isA<PostgrestException>()),
        reason: '$table/$slug удалился из-под события',
      );
    }
    // Событие убрали — те же объекты удаляются.
    await a.from('events').delete().eq('id', ambush.id);
    for (final (table, slug) in [
      ('locations', 'shtolnya_3'),
      ('characters', 'slizen'),
      ('items', 'klyuch'),
    ]) {
      expect(
        await a.from(table).delete().eq('id', id(s, slug)).select(),
        hasLength(1),
        reason: '$table/$slug',
      );
    }
  });

  test('правка события — в мире и в истории, откат — как было', () async {
    final s = await w();
    final before = show(s);
    await repo.applyManualEdit(
      world.id,
      editEvent(
        world.id,
        ambush,
        NewEvent(
          title: 'Засада',
          description: ambush.description,
          locationId: id(s, 'rynok'),
          enemies: [
            EventEnemy(characterId: id(s, 'slizen'), amount: 5),
          ],
          itemIds: [id(s, 'kirka')],
        ),
        {
          for (final c in s.characters) c.id: c.slug,
          for (final i in s.items) i.id: i.slug,
        },
      ),
    );
    expect(show(await w()), 'Засада @ Рынок | Слизень × 5 | Кирка');
    final set = (await repo.history(world.id)).first;
    expect(set.request, 'Правка вручную: Засада');
    expect(
      [for (final op in set.ops) '${op.action} ${op.type} ${op.label}'],
      [
        'update event zasada_u_lebedki',
        'update event_enemy zasada_u_lebedki/slizen',
        'delete event_item zasada_u_lebedki/klyuch',
        'create event_item zasada_u_lebedki/kirka',
      ],
    );

    await revertLast();
    expect(show(await w()), before);
  });

  test('удаление события — враги и предметы в журнале; откат возвращает '
      'событие целиком', () async {
    final before = show(await w());
    await repo.applyManualEdit(
      world.id,
      deleteObject(
        world.id,
        type: 'event',
        id: ambush.id,
        slug: ambush.slug,
        title: ambush.title,
      ),
    );
    expect((await w()).events, isEmpty);
    expect(
      [
        for (final op in (await repo.history(world.id)).first.ops)
          '${op.action} ${op.type} ${op.label}',
      ],
      [
        'delete event_enemy zasada_u_lebedki/slizen',
        'delete event_item zasada_u_lebedki/klyuch',
        'delete event zasada_u_lebedki',
      ],
    );

    await revertLast();
    final back = await w();
    expect(show(back), before);
    // Откат вернул те же строки, с прежними id.
    expect(back.events.single.id, ambush.id);
    expect(back.events.single.enemies.single.id, ambush.enemies.single.id);
  });
}
