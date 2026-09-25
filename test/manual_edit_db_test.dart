// Ручная правка и удаление в НАСТОЯЩЕЙ базе (4.1): набором в историю, откат —
// мир как был; удаление объекта со ссылками — ошибка; правка после набора —
// откат того набора упирается в конфликт.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/history.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/content/quest.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'autofix_test.dart' show floodWithAttack;
import 'change_set_db_test.dart' show draft;
import 'db_helpers.dart';
import 'revert_db_test.dart' show full;

void main() {
  late SupabaseClient a;
  late SupabaseClient b;
  late World world;
  late SupabaseContentRepo repo;

  setUpAll(() async {
    (a, b) = await twoAuthors();
    repo = SupabaseContentRepo(a);
  });

  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Правка ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    await fillMines(repo, world.id);
  });

  tearDown(() => a.from('projects').delete().eq('id', world.id));

  Future<WorldSnapshot> w() => repo.snapshot(world.id);
  Future<void> revertLast() async =>
      repo.revertChangeSet(world.id, (await repo.history(world.id)).first.id);
  T by<T>(List<T> list, String Function(T) slug, String s) =>
      list.firstWhere((x) => slug(x) == s);
  Map<String, String> itemSlugs(WorldSnapshot s) => {
    for (final i in s.items) i.id: i.slug,
  };

  test(
    'правка вручную: локация — в мире и в истории, откат — как было',
    () async {
      final before = await w();
      final shaft = by(before.locations, (x) => x.slug, 'shtolnya_3');
      await repo.applyManualEdit(
        world.id,
        editLocation(
          world.id,
          shaft,
          const NewLocation(
            title: 'Штольня №3',
            description: 'затоплена',
            levelMin: 2,
            levelMax: 5,
          ),
        ),
      );
      final after = by((await w()).locations, (x) => x.slug, 'shtolnya_3');
      expect((after.description, after.levelMax), ('затоплена', 5));
      final set = (await repo.history(world.id)).single;
      expect(set.request, 'Правка вручную: Штольня №3');
      expect(set.ops.single.changes.map((c) => c.$1).toSet(), {
        'description',
        'level_max',
      });
      await revertLast();
      expect(full(await w()), full(before));
    },
  );

  test(
    'правка вручную: персонаж — убрать локацию, шанс, добыча; откат',
    () async {
      final before = await w();
      final slime = by(before.characters, (x) => x.slug, 'slizen');
      final pick = by(before.items, (x) => x.slug, 'kirka');
      final key = by(before.items, (x) => x.slug, 'klyuch');
      await repo.applyManualEdit(
        world.id,
        editCharacter(
          world.id,
          slime,
          NewCharacter(
            title: 'Слизень',
            description: 'сбежал',
            role: Role.enemy,
            locationId: null,
            level: 2,
            hp: 12,
            attack: 5,
            loot: [
              LootDrop(itemId: key.id, chance: 50),
              LootDrop(itemId: pick.id, chance: 5),
            ],
          ),
          itemSlugs(before),
        ),
      );
      final now = by((await w()).characters, (x) => x.slug, 'slizen');
      expect(now.locationId, isNull);
      expect(
        {for (final l in now.loot) l.itemId: l.chance},
        {key.id: 50, pick.id: 5},
      );
      await revertLast();
      expect(full(await w()), full(before));
    },
  );

  test(
    'правка вручную: квест — шаги по-новому, награда другая; откат',
    () async {
      final before = await w();
      final q = by(before.quests, (x) => x.slug, 'obval');
      final key = by(before.items, (x) => x.slug, 'klyuch');
      await repo.applyManualEdit(
        world.id,
        editQuest(
          world.id,
          q,
          NewQuest(
            title: 'Обвал',
            description: 'короче',
            giverId: q.giverId!,
            steps: [q.steps[2], q.steps[0]],
            rewardIds: [key.id],
          ),
        ),
      );
      final now = by((await w()).quests, (x) => x.slug, 'obval');
      expect(now.steps.map((s) => s.kind), [StepKind.collect, StepKind.talk]);
      expect(now.rewardIds, [key.id]);
      await revertLast();
      expect(full(await w()), full(before));
    },
  );

  test(
    'удаление вручную: объект со ссылками — ошибка, мир не тронут',
    () async {
      final before = await w();
      final key = by(before.items, (x) => x.slug, 'klyuch');
      expect(referencesTo(before, key.id), isNotEmpty);
      await expectLater(
        repo.applyManualEdit(
          world.id,
          deleteObject(
            world.id,
            type: 'item',
            id: key.id,
            slug: key.slug,
            title: key.title,
          ),
        ),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23503'),
        ),
      );
      expect(full(await w()), full(before));
      expect(await repo.history(world.id), isEmpty);
    },
  );

  test(
    'удаление вручную: квест ушёл с шагами и наградой; откат вернул',
    () async {
      final before = await w();
      final q = by(before.quests, (x) => x.slug, 'obval');
      await repo.applyManualEdit(
        world.id,
        deleteObject(
          world.id,
          type: 'quest',
          id: q.id,
          slug: q.slug,
          title: q.title,
        ),
      );
      expect((await w()).quests, isEmpty);
      expect((await repo.history(world.id)).single.ops.map((o) => o.label), [
        'obval#3',
        'obval#2',
        'obval#1',
        'obval/kirka',
        'obval',
      ]);
      await revertLast();
      expect(full(await w()), full(before));
    },
  );

  test(
    'правка вручную после затопления — откат затопления: конфликт',
    () async {
      await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
      final flood = (await repo.history(world.id)).single;
      final flooded = await w();
      final shaft = by(flooded.locations, (x) => x.slug, 'shtolnya_3');
      await repo.applyManualEdit(
        world.id,
        editLocation(
          world.id,
          shaft,
          const NewLocation(
            title: 'Штольня №3',
            description: 'осушили',
            levelMin: 2,
            levelMax: 4,
          ),
        ),
      );
      expect(
        (await repo.revertConflicts(world.id, flood.id)).map((c) => c.message),
        ['shtolnya_3 — изменён после набора'],
      );
      await expectLater(
        repo.revertChangeSet(world.id, flood.id),
        throwsA(isA<PostgrestException>()),
      );
      expect((await repo.history(world.id)).map((s) => s.status), [
        SetStatus.applied,
        SetStatus.applied,
      ]);
    },
  );

  test('правка вручную: чужой автор не правит чужой мир', () async {
    final before = await w();
    final shaft = by(before.locations, (x) => x.slug, 'shtolnya_3');
    await expectLater(
      SupabaseContentRepo(b).applyManualEdit(
        world.id,
        editLocation(
          world.id,
          shaft,
          const NewLocation(
            title: 'Моя',
            description: '',
            levelMin: 1,
            levelMax: 1,
          ),
        ),
      ),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    expect(full(await w()), full(before));
  });
}
