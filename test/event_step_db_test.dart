// Шаг квеста «пройти событие» в НАСТОЯЩЕЙ базе (5б.3): ложится в базу, держит событие,
// откатывается; база не пускает шаг без события, с лишней целью, с количеством; план
// ассистента, сменивший вид такого шага, освобождает событие.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/content/quest.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'change_set_db_test.dart' show draft;
import 'db_helpers.dart';

void main() {
  late SupabaseClient a;
  late World world;
  late SupabaseContentRepo repo;
  late Event ambush;

  setUpAll(() async {
    a = await testAuthor();
    repo = SupabaseContentRepo(a);
  });

  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Шаг ${DateTime.now().microsecondsSinceEpoch}',
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

  String id(WorldSnapshot s, String slug) => [
    ...s.locations.map((x) => (x.slug, x.id)),
    ...s.items.map((x) => (x.slug, x.id)),
    ...s.characters.map((x) => (x.slug, x.id)),
  ].firstWhere((x) => x.$1 == slug).$2;

  /// Квест «Обвал» получает четвёртый шаг — пройти «Засаду у лебёдки».
  Future<void> addEventStep() async {
    final q = (await w()).quests.single;
    await repo.applyManualEdit(
      world.id,
      editQuest(
        world.id,
        q,
        NewQuest(
          title: q.title,
          description: q.description,
          giverId: q.giverId!,
          steps: [
            ...q.steps,
            QuestStep(kind: StepKind.event, targetId: ambush.id),
          ],
          rewardIds: q.rewardIds,
        ),
      ),
    );
  }

  String steps(WorldSnapshot s) => [
    for (final st in s.quests.single.steps)
      '${st.kind.name}:${s.titles[st.targetId]}',
  ].join(' → ');

  test('шаг «пройти событие»: ложится в базу, держит событие, откат убирает шаг', () async {
    final before = steps(await w());
    await addEventStep();
    expect(steps(await w()), '$before → event:Засада у лебёдки');

    // Событие под шагом квеста база удалить не даёт — и набором, и напрямую.
    await expectLater(
      repo.applyManualEdit(
        world.id,
        deleteObject(
          world.id,
          type: 'event',
          id: ambush.id,
          slug: ambush.slug,
          title: ambush.title,
        ),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect((await w()).events, hasLength(1));

    await revertLast();
    expect(steps(await w()), before);
  });

  test('новый квест с шагом «пройти событие» создаётся одной транзакцией', () async {
    final s = await w();
    final q = await repo.createQuest(
      world.id,
      NewQuest(
        title: 'Лебёдка',
        description: '',
        giverId: id(s, 'brigadir'),
        steps: [QuestStep(kind: StepKind.event, targetId: ambush.id)],
      ),
    );
    final back = (await w()).quests.firstWhere((x) => x.id == q.id);
    expect(back.steps.single.kind, StepKind.event);
    expect(back.steps.single.targetId, ambush.id);
  });

  test('база не пускает шаг «пройти событие» без события, с лишней целью, '
      'с количеством', () async {
    final s = await w();
    final quest = s.quests.single;
    Future<void> refused(String what, Map<String, dynamic> row) => expectLater(
      a.from('quest_steps').insert({
        'project_id': world.id,
        'quest_id': quest.id,
        'position': quest.steps.length + 1,
        'kind': 'event',
        ...row,
      }),
      throwsA(isA<PostgrestException>()),
      reason: what,
    );
    await refused('без события', {});
    await refused('с лишней целью', {
      'event_id': ambush.id,
      'character_id': id(s, 'slizen'),
    });
    await refused('с количеством', {'event_id': ambush.id, 'amount': 2});
    await refused('старый вид шага с событием', {
      'kind': 'visit',
      'location_id': id(s, 'shtolnya_3'),
      'event_id': ambush.id,
    });
    expect((await w()).quests.single.steps, hasLength(quest.steps.length));
  });

  test('план ассистента меняет вид шага «пройти событие» — шаг больше не '
      'держит событие', () async {
    await addEventStep();
    final position = (await w()).quests.single.steps.length;
    await repo.applyChangeSet(
      world.id,
      draft(
        Plan(
          summary: 'шаг 4 — прийти в штольню',
          ops: [
            PlanOp(
              action: OpAction.update,
              type: OpType.questStep,
              quest: 'obval',
              position: position,
              fields: const {'step_kind': 'visit', 'target': 'shtolnya_3'},
            ),
          ],
        ),
      ),
    );
    expect(steps(await w()), endsWith('visit:Штольня №3'));
    // Событие свободно: его снова можно удалить.
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
    // Откат удаления и откат плана возвращают шаг вместе со ссылкой на событие.
    await revertLast();
    await repo.revertChangeSet(world.id, (await repo.history(world.id))[2].id);
    expect(steps(await w()), endsWith('event:Засада у лебёдки'));
  });
}
