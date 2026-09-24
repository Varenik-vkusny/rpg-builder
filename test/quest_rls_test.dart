// Квесты в НАСТОЯЩЕЙ базе Supabase: запреты базы и изоляция (RLS), два автора.
// Авторы и переменные окружения — в db_helpers.dart.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/quest.dart';
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
        title: 'Квесты ${DateTime.now().microsecondsSinceEpoch}',
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
        description: '',
        levelMin: 2,
        levelMax: 4,
      ),
    );
  });

  // Удаление мира уносит всё его содержимое (on delete cascade).
  tearDownAll(() => a.from('projects').delete().eq('id', world.id));

  group('квесты', () {
    late Item winchKey;
    late Item pick;
    late Character foreman;
    late Character slime;
    late Quest quest;

    setUpAll(() async {
      final repo = SupabaseContentRepo(a);
      winchKey = await repo.createItem(
        world.id,
        const NewItem(
          title: 'Ключ от лебёдки',
          kind: ItemKind.quest,
          rarity: Rarity.common,
          level: 2,
          price: 0,
        ),
      );
      pick = await repo.createItem(
        world.id,
        const NewItem(
          title: 'Кирка',
          kind: ItemKind.weapon,
          rarity: Rarity.rare,
          level: 3,
          damage: 6,
          price: 40,
        ),
      );
      foreman = await repo.createCharacter(
        world.id,
        const NewCharacter(
          title: 'Бригадир Эрден',
          description: '',
          role: Role.npc,
          locationId: null,
        ),
      );
      slime = await repo.createCharacter(
        world.id,
        NewCharacter(
          title: 'Пепельный слизень',
          description: '',
          role: Role.enemy,
          locationId: shaft.id,
        ),
      );
      quest = await repo.createQuest(
        world.id,
        NewQuest(
          title: 'Обвал в третьей штольне',
          description: '',
          giverId: foreman.id,
          steps: [
            QuestStep(kind: StepKind.talk, targetId: foreman.id),
            QuestStep(kind: StepKind.kill, targetId: slime.id, amount: 4),
            QuestStep(kind: StepKind.collect, targetId: winchKey.id, amount: 1),
            QuestStep(kind: StepKind.visit, targetId: shaft.id),
          ],
          rewardIds: [pick.id],
        ),
      );
    });

    /// Прямой вызов транзакции в базе в обход формы.
    Future<void> rawCreate(
      SupabaseClient who,
      String slug, {
      String? giver,
      required List<Map<String, dynamic>> steps,
    }) => who.rpc(
      'create_quest',
      params: {
        'p_project_id': world.id,
        'p_slug': slug,
        'p_title': slug,
        'p_description': '',
        'p_giver_id': giver ?? foreman.id,
        'p_steps': steps,
        'p_rewards': const [],
      },
    );

    // Причины отказа базы: права (RLS), ограничение таблицы, проверка функции.
    const byRls = '42501', byCheck = '23514', byFunction = 'P0001';

    /// База отклоняет квест по причине [code] и не оставляет от него ничего
    /// (одна транзакция). Код отсекает отказ по посторонней причине.
    Future<void> expectRejected(
      Future<void> call,
      String slug,
      String code,
    ) async {
      await expectLater(
        call,
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', code)),
      );
      expect(await a.from('quests').select().eq('slug', slug), isEmpty);
    }

    test('автор видит квест: выдающий, шаги по порядку, награда', () async {
      final mine = await SupabaseContentRepo(a).quests(world.id);
      final got = mine.singleWhere((q) => q.id == quest.id);
      expect(got.slug, 'obval_v_tretey_shtolne');
      expect(got.giverId, foreman.id);
      expect(got.steps.map((s) => s.kind), [
        StepKind.talk,
        StepKind.kill,
        StepKind.collect,
        StepKind.visit,
      ]);
      expect(got.steps.map((s) => s.targetId), [
        foreman.id,
        slime.id,
        winchKey.id,
        shaft.id,
      ]);
      expect(got.steps.map((s) => s.amount), [null, 4, 1, null]);
      expect(got.rewardIds, [pick.id]);
    });

    test('slug квеста не меняется после создания', () async {
      await expectSlugLocked(a, 'quests', quest.id, 'obval_v_tretey_shtolne');
    });

    test('база не принимает врага выдающим', () async {
      await expectRejected(
        rawCreate(
          a,
          'vrag_vydaet',
          giver: slime.id,
          steps: [
            {'kind': 'talk', 'character_id': foreman.id},
          ],
        ),
        'vrag_vydaet',
        byRls,
      );
    });

    test('база не принимает квест без шагов', () async {
      await expectRejected(
        rawCreate(a, 'bez_shagov', steps: []),
        'bez_shagov',
        byFunction,
      );
    });

    test('база не принимает квест без шагов и в обход функции', () async {
      await expectRejected(
        a.from('quests').insert({
          'project_id': world.id,
          'slug': 'pustoy_napryamuyu',
          'title': 'Пустой',
          'giver_id': foreman.id,
        }),
        'pustoy_napryamuyu',
        byFunction,
      );
    });

    final wrongSteps = <String, (String, Map<String, dynamic> Function())>{
      'поговорить с предметом': (
        byCheck,
        () => {'kind': 'talk', 'item_id': winchKey.id},
      ),
      'собрать с двумя целями': (
        byCheck,
        () => {
          'kind': 'collect',
          'item_id': winchKey.id,
          'character_id': foreman.id,
          'amount': 1,
        },
      ),
      'убить без количества': (
        byCheck,
        () => {'kind': 'kill', 'character_id': slime.id},
      ),
      'убить 0': (
        byCheck,
        () => {'kind': 'kill', 'character_id': slime.id, 'amount': 0},
      ),
      'прийти без цели': (byCheck, () => {'kind': 'visit'}),
      'убить жителя': (
        byRls,
        () => {'kind': 'kill', 'character_id': foreman.id, 'amount': 1},
      ),
    };
    wrongSteps.forEach((name, bad) {
      final (code, step) = bad;
      test('база не принимает шаг «$name» и не оставляет квест', () async {
        final slug = 'plokhoy_${name.hashCode.abs()}';
        await expectRejected(
          rawCreate(
            a,
            slug,
            steps: [
              {'kind': 'talk', 'character_id': foreman.id},
              step(),
            ],
          ),
          slug,
          code,
        );
      });
    });

    test('второй автор чужой квест, шаги и награды не видит', () async {
      expect(await SupabaseContentRepo(b).quests(world.id), isEmpty);
      expect(await b.from('quests').select().eq('id', quest.id), isEmpty);
      expect(
        await b.from('quest_steps').select().eq('quest_id', quest.id),
        isEmpty,
      );
      expect(
        await b.from('quest_rewards').select().eq('quest_id', quest.id),
        isEmpty,
      );
    });

    test('второй автор не может создать квест в чужом мире', () async {
      await expectLater(
        rawCreate(
          b,
          'podkidysh',
          steps: [
            {'kind': 'talk', 'character_id': foreman.id},
          ],
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('без входа квесты, шаги и награды не читаются', () async {
      expect(await anonymous().from('quests').select(), isEmpty);
      expect(await anonymous().from('quest_steps').select(), isEmpty);
      expect(await anonymous().from('quest_rewards').select(), isEmpty);
    });
  });
}
