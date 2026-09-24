// Изоляция содержимого мира в НАСТОЯЩЕЙ базе Supabase (RLS): два тестовых автора.
// Авторы и переменные окружения — в db_helpers.dart.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'db_helpers.dart';

void main() {
  late SupabaseClient a;
  late SupabaseClient b;
  late World world;
  late Location shaft;

  setUpAll(() async {
    (a, b) = await twoAuthors();
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Содержимое ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 7,
      ),
    );
    shaft = await SupabaseContentRepo(a).createLocation(
      world.id,
      const NewLocation(
        title: 'Штольня №3',
        description: 'Сырая',
        levelMin: 2,
        levelMax: 4,
      ),
    );
  });

  // Удаление мира уносит всё его содержимое (on delete cascade).
  tearDownAll(() => a.from('projects').delete().eq('id', world.id));

  group('локации', () {
    test('автор видит свою локацию со slug', () async {
      final mine = await SupabaseContentRepo(a).locations(world.id);
      expect(mine.map((l) => l.slug), ['shtolnya_3']);
      expect(mine.single.levelMin, 2);
      expect(mine.single.levelMax, 4);
    });

    test('одинаковые названия получают разные slug', () async {
      final twin = await SupabaseContentRepo(a).createLocation(
        world.id,
        const NewLocation(
          title: 'Штольня №3',
          description: '',
          levelMin: 1,
          levelMax: 1,
        ),
      );
      expect(twin.slug, 'shtolnya_3_2');
      await a.from('locations').delete().eq('id', twin.id);
    });

    test('второй автор чужую локацию не видит', () async {
      expect(await SupabaseContentRepo(b).locations(world.id), isEmpty);
      expect(await b.from('locations').select().eq('id', shaft.id), isEmpty);
    });

    test('второй автор не может создать локацию в чужом мире', () async {
      await expectLater(
        b.from('locations').insert({
          'project_id': world.id,
          'slug': 'podkidysh',
          'title': 'Подкидыш',
          'level_min': 1,
          'level_max': 1,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('slug локации не меняется после создания', () async {
      await expectSlugLocked(a, 'locations', shaft.id, 'shtolnya_3');
    });

    test('без входа локации не читаются', () async {
      expect(await anonymous().from('locations').select(), isEmpty);
    });
  });

  group('предметы', () {
    late Item key;

    setUpAll(() async {
      key = await SupabaseContentRepo(a).createItem(
        world.id,
        const NewItem(
          title: 'Ключ от лебёдки',
          kind: ItemKind.quest,
          rarity: Rarity.common,
          level: 2,
          price: 0,
        ),
      );
    });

    test('автор видит свой предмет со slug и полями', () async {
      final mine = await SupabaseContentRepo(a).items(world.id);
      final got = mine.singleWhere((i) => i.id == key.id);
      expect(got.slug, 'klyuch_ot_lebedki');
      expect(got.kind, ItemKind.quest);
      expect(got.level, 2);
      expect(got.damage, isNull);
    });

    test('у оружия есть урон, защиты нет', () async {
      final pick = await SupabaseContentRepo(a).createItem(
        world.id,
        const NewItem(
          title: 'Кирка',
          kind: ItemKind.weapon,
          rarity: Rarity.rare,
          level: 3,
          damage: 6,
          defense: 99,
          price: 40,
        ),
      );
      expect(pick.damage, 6);
      expect(pick.defense, isNull);
    });

    test('база не принимает урон у квестового предмета', () async {
      await expectLater(
        a.from('items').insert({
          'project_id': world.id,
          'slug': 'strannyy_klyuch',
          'title': 'Странный ключ',
          'kind': 'quest',
          'rarity': 'common',
          'level': 1,
          'damage': 5,
          'price': 0,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('slug предмета не меняется после создания', () async {
      await expectSlugLocked(a, 'items', key.id, 'klyuch_ot_lebedki');
    });

    test('второй автор чужой предмет не видит', () async {
      expect(await SupabaseContentRepo(b).items(world.id), isEmpty);
      expect(await b.from('items').select().eq('id', key.id), isEmpty);
    });

    test('второй автор не может создать предмет в чужом мире', () async {
      await expectLater(
        b.from('items').insert({
          'project_id': world.id,
          'slug': 'podkidysh',
          'title': 'Подкидыш',
          'kind': 'misc',
          'rarity': 'common',
          'level': 1,
          'price': 0,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('без входа предметы не читаются', () async {
      expect(await anonymous().from('items').select(), isEmpty);
    });
  });

  group('персонажи', () {
    late Item key;
    late Character slime;

    setUpAll(() async {
      key = await SupabaseContentRepo(a).createItem(
        world.id,
        const NewItem(
          title: 'Ключ от лебёдки',
          kind: ItemKind.quest,
          rarity: Rarity.common,
          level: 2,
          price: 0,
        ),
      );
      slime = await SupabaseContentRepo(a).createCharacter(
        world.id,
        NewCharacter(
          title: 'Пепельный слизень',
          description: '',
          role: Role.enemy,
          locationId: shaft.id,
          loot: [LootDrop(itemId: key.id, chance: 35)],
        ),
      );
    });

    /// Прямой вызов транзакции в базе в обход формы.
    Future<void> rawCreate(
      SupabaseClient who,
      String slug,
      String role,
      List<Map<String, dynamic>> loot,
    ) => who.rpc(
      'create_character',
      params: {
        'p_project_id': world.id,
        'p_slug': slug,
        'p_title': slug,
        'p_description': '',
        'p_role': role,
        'p_location_id': null,
        'p_loot': loot,
      },
    );

    test('автор видит врага с локацией, slug и добычей 35%', () async {
      final mine = await SupabaseContentRepo(a).characters(world.id);
      final got = mine.singleWhere((c) => c.id == slime.id);
      expect(got.slug, 'pepelnyy_slizen');
      expect(got.role, Role.enemy);
      expect(got.locationId, shaft.id);
      expect(got.loot.single.itemId, key.id);
      expect(got.loot.single.chance, 35);
    });

    for (final bad in [0, -1, 100.5]) {
      test('база не принимает шанс $bad и не оставляет персонажа', () async {
        final slug =
            'bad_chance_${bad.toString().replaceAll(RegExp(r'\W'), '_')}';
        await expectLater(
          rawCreate(a, slug, 'enemy', [
            {'item_id': key.id, 'chance': bad},
          ]),
          throwsA(isA<PostgrestException>()),
        );
        // Транзакция: без добычи не остался и сам персонаж.
        expect(await a.from('characters').select().eq('slug', slug), isEmpty);
      });
    }

    test('база принимает шанс ровно 100', () async {
      await rawCreate(a, 'full_chance', 'enemy', [
        {'item_id': key.id, 'chance': 100},
      ]);
      final rows = await a
          .from('characters')
          .select('loot(chance)')
          .eq('project_id', world.id)
          .eq('slug', 'full_chance');
      expect(rows.single['loot'].single['chance'], 100);
    });

    test('добычу задают только врагу', () async {
      await expectLater(
        rawCreate(a, 'zhitel_s_dobychey', 'npc', [
          {'item_id': key.id, 'chance': 50},
        ]),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        await a.from('characters').select().eq('slug', 'zhitel_s_dobychey'),
        isEmpty,
      );
    });

    test('slug персонажа не меняется после создания', () async {
      await expectSlugLocked(a, 'characters', slime.id, 'pepelnyy_slizen');
    });

    test('второй автор чужого персонажа и добычу не видит', () async {
      expect(await SupabaseContentRepo(b).characters(world.id), isEmpty);
      expect(await b.from('characters').select().eq('id', slime.id), isEmpty);
      expect(
        await b.from('loot').select().eq('character_id', slime.id),
        isEmpty,
      );
    });

    test('второй автор не может создать персонажа в чужом мире', () async {
      await expectLater(
        rawCreate(b, 'podkidysh', 'enemy', const []),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('без входа персонажи и добыча не читаются', () async {
      expect(await anonymous().from('characters').select(), isEmpty);
      expect(await anonymous().from('loot').select(), isEmpty);
    });
  });
}
