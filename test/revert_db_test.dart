// Откат набора в НАСТОЯЩЕЙ базе (3.7, правило 6): обратный набор через apply_ops,
// одной транзакцией, в историю; объект меняли после набора — конфликт, мир не тронут.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/history.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'autofix_test.dart' show floodWithAttack;
import 'change_set_db_test.dart' show draft;
import 'db_helpers.dart';

/// Мир целиком строками — всё, что меняет план или откат, включая награды и порядок шагов.
List<String> full(WorldSnapshot w) {
  final t = w.titles;
  return [
    for (final l in w.locations)
      'L ${l.slug}:${l.title}:${l.description}:${l.levelMin}-${l.levelMax}',
    for (final i in w.items) 'I ${i.slug}:${i.title}:${i.damage}:${i.price}',
    for (final c in w.characters)
      'C ${c.slug}:${c.role.name}:${t[c.locationId]}:${c.level}:${c.hp}:${c.attack}:'
          '${c.loot.map((l) => '${t[l.itemId]}${l.chanceLabel}')}',
    for (final q in w.quests)
      'Q ${q.slug}:${t[q.giverId]}:'
          '${q.steps.map((s) => '${s.kind.name}>${t[s.targetId]}×${s.amount}')}:'
          '${q.rewardIds.map((id) => t[id])}',
  ]..sort();
}

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
        title: 'Откат ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    await fillMines(repo, world.id);
  });

  tearDown(() => a.from('projects').delete().eq('id', world.id));

  Future<List<String>> now() async => full(await repo.snapshot(world.id));

  test('откат: затопление применено и откачено — мир как был', () async {
    final before = await now();
    await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
    expect(await now(), isNot(before));
    final flood = (await repo.history(world.id)).single;
    expect(await repo.revertConflicts(world.id, flood.id), isEmpty);
    await repo.revertChangeSet(world.id, flood.id);
    expect(await now(), before);

    final h = await repo.history(world.id);
    expect(h.map((s) => s.status), [SetStatus.applied, SetStatus.reverted]);
    expect(h.first.revertsId, flood.id);
    expect(h.first.summary, 'Откат: ${flood.summary}');
    // Обратный набор — в журнале, с «было → стало», с конца исходного.
    expect(h.first.ops.map((o) => '${o.action} ${o.type} ${o.label}'), [
      'update quest_step obval#2',
      'delete loot utoplennik/klyuch',
      'create loot slizen/klyuch',
      'delete character utoplennik',
      'update location shtolnya_3',
    ]);
  });

  test(
    'откат: удалённый квест вернулся с шагами по порядку и наградой',
    () async {
      final before = await now();
      await repo.applyChangeSet(
        world.id,
        draft(
          const Plan(
            summary: 'убрать обвал',
            ops: [
              PlanOp(
                action: OpAction.delete,
                type: OpType.quest,
                slug: 'obval',
              ),
            ],
          ),
        ),
      );
      expect(await now(), isNot(before));
      await repo.revertChangeSet(
        world.id,
        (await repo.history(world.id)).single.id,
      );
      expect(await now(), before);
    },
  );

  test(
    'откат: удалённый шаг вернулся на своё место, следующие сдвинулись',
    () async {
      final before = await now();
      await repo.applyChangeSet(
        world.id,
        draft(
          const Plan(
            summary: 'без второго шага',
            ops: [
              PlanOp(
                action: OpAction.delete,
                type: OpType.questStep,
                quest: 'obval',
                position: 2,
              ),
            ],
          ),
        ),
      );
      await repo.revertChangeSet(
        world.id,
        (await repo.history(world.id)).single.id,
      );
      expect(await now(), before);
    },
  );

  test('откат: объект меняли после набора — конфликт, мир не тронут', () async {
    await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
    final flood = (await repo.history(world.id)).single;
    // Автор после набора поправил штольню руками.
    await a
        .from('locations')
        .update({'description': 'осушили'})
        .eq('project_id', world.id)
        .eq('slug', 'shtolnya_3');
    final edited = await now();

    final conflicts = await repo.revertConflicts(world.id, flood.id);
    expect(conflicts.map((c) => c.message), [
      'shtolnya_3 — изменён после набора',
    ]);
    await expectLater(
      repo.revertChangeSet(world.id, flood.id),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('конфликт отката: shtolnya_3'),
        ),
      ),
    );
    expect(await now(), edited);
    expect((await repo.history(world.id)).map((s) => s.status), [
      SetStatus.applied,
    ]);
  });

  test('откат: отклонённый и уже откаченный не откатить', () async {
    await repo.rejectChangeSet(world.id, draft(floodWithAttack(8)));
    final rejected = (await repo.history(world.id)).single;
    await expectLater(
      repo.revertChangeSet(world.id, rejected.id),
      throwsA(isA<PostgrestException>()),
    );
    await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
    final applied = (await repo.history(world.id)).first;
    await repo.revertChangeSet(world.id, applied.id);
    await expectLater(
      repo.revertChangeSet(world.id, applied.id),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('откат: откат отката возвращает затопление', () async {
    await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
    final flooded = await now();
    final flood = (await repo.history(world.id)).single;
    await repo.revertChangeSet(world.id, flood.id);
    final undo = (await repo.history(world.id)).first;
    await repo.revertChangeSet(world.id, undo.id);
    expect(await now(), flooded);
  });

  test('откат: чужой автор не откатит чужой набор', () async {
    await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
    final flooded = await now();
    final flood = (await repo.history(world.id)).single;
    await expectLater(
      SupabaseContentRepo(b).revertChangeSet(world.id, flood.id),
      throwsA(isA<PostgrestException>()),
    );
    expect(await now(), flooded);
  });

  test('откат: журнал наборов не переписать прямой правкой', () async {
    await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
    final flood = (await repo.history(world.id)).single;
    await expectLater(
      a
          .from('change_sets')
          .update({'summary': 'ничего не было'})
          .eq('id', flood.id),
      throwsA(isA<PostgrestException>()),
    );
    expect((await repo.history(world.id)).single.summary, flood.summary);
  });

  test(
    'откат: «Откачен» прямой правкой не поставить — только самим откатом',
    () async {
      await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
      final flooded = await now();
      final flood = (await repo.history(world.id)).single;
      await expectLater(
        a.from('change_sets').update({'status': 'reverted'}).eq('id', flood.id),
        throwsA(isA<PostgrestException>()),
      );
      // И поддельный «откат набора» без отката мира база не примет.
      await expectLater(
        a.from('change_sets').insert({
          'project_id': world.id,
          'scope_type': 'location',
          'scope_slug': 'shtolnya_3',
          'request': 'x',
          'status': 'applied',
          'reverts_id': flood.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        a.from('change_sets').insert({
          'project_id': world.id,
          'scope_type': 'location',
          'scope_slug': 'shtolnya_3',
          'request': 'x',
          'status': 'reverted',
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect((await repo.history(world.id)).map((s) => s.status), [
        SetStatus.applied,
      ]);
      expect(await now(), flooded);
    },
  );
}
