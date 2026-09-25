// Журнал наборов в НАСТОЯЩЕЙ базе — то, без чего откат (3.7) не восстановит мир:
// подписи операций одинаковы у применённых и отклонённых наборов; удаление объекта
// пишет в журнал и связи, ушедшие вместе с ним; у врага с добычей роль не меняется.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'autofix_test.dart' show floodWithAttack;
import 'change_set_db_test.dart' show draft;
import 'db_helpers.dart';

Plan only(PlanOp op) => Plan(summary: 'одна операция', ops: [op]);

void main() {
  late SupabaseClient a;
  late World world;
  late SupabaseContentRepo repo;

  setUpAll(() async {
    (a, _) = await twoAuthors();
    repo = SupabaseContentRepo(a);
  });

  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Журнал ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    await fillMines(repo, world.id);
  });

  tearDown(() => a.from('projects').delete().eq('id', world.id));

  /// Операции последнего набора: «действие вид подпись».
  Future<List<String>> lastOps() async {
    final set = await a
        .from('change_sets')
        .select('id')
        .eq('project_id', world.id)
        .order('created_at', ascending: false)
        .limit(1)
        .single();
    final ops = await a
        .from('change_ops')
        .select()
        .eq('change_set_id', set['id'])
        .order('position', ascending: true);
    return [
      for (final o in ops)
        '${o['action']} ${o['object_type']} ${o['object_slug']}',
    ];
  }

  test('журнал: отклонённый набор подписан так же, как применённый', () async {
    await repo.rejectChangeSet(world.id, draft(floodWithAttack(8)));
    expect(await lastOps(), [
      'update location shtolnya_3',
      'create character utoplennik',
      'delete loot slizen/klyuch',
      'create loot utoplennik/klyuch',
      'update quest_step obval#2',
    ]);
  });

  test('журнал: удаление квеста пишет и его шаги, и награды', () async {
    await repo.applyChangeSet(
      world.id,
      draft(
        only(
          const PlanOp(
            action: OpAction.delete,
            type: OpType.quest,
            slug: 'obval',
          ),
        ),
      ),
    );
    final ops = await lastOps();
    // Шаги — с конца: откат вернёт их в обратном порядке, с первого.
    expect(ops, [
      'delete quest_step obval#3',
      'delete quest_step obval#2',
      'delete quest_step obval#1',
      'delete quest_reward obval/kirka',
      'delete quest obval',
    ]);
  });

  test('журнал: удаление врага пишет и его добычу', () async {
    // Крот — враг с добычей, на него ничего не ссылается.
    await repo.applyChangeSet(
      world.id,
      draft(
        const Plan(
          summary: 'крот',
          ops: [
            PlanOp(
              action: OpAction.create,
              type: OpType.character,
              slug: 'krot',
              fields: {'title': 'Крот', 'role': 'enemy', 'level': 2},
            ),
            PlanOp(
              action: OpAction.create,
              type: OpType.loot,
              character: 'krot',
              item: 'kirka',
              fields: {'chance': 12.5},
            ),
          ],
        ),
      ),
    );
    await repo.applyChangeSet(
      world.id,
      draft(
        only(
          const PlanOp(
            action: OpAction.delete,
            type: OpType.character,
            slug: 'krot',
          ),
        ),
      ),
    );
    expect(await lastOps(), ['delete loot krot/kirka', 'delete character krot']);
    final loot = await a
        .from('change_ops')
        .select('before')
        .eq('project_id', world.id)
        .eq('object_slug', 'krot/kirka')
        .eq('action', 'delete')
        .single();
    expect(loot['before']['chance'], 12.5);
  });

  test('журнал: у врага с добычей роль прямой правкой не сменить', () async {
    await expectLater(
      a
          .from('characters')
          .update({'role': 'npc'})
          .eq('project_id', world.id)
          .eq('slug', 'slizen'),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('у врага есть добыча'),
        ),
      ),
    );
    final slime = await a
        .from('characters')
        .select('role')
        .eq('project_id', world.id)
        .eq('slug', 'slizen')
        .single();
    expect(slime['role'], 'enemy');
  });

  test('журнал: враг без добычи роль сменить может', () async {
    await a
        .from('loot')
        .delete()
        .eq('project_id', world.id);
    await a
        .from('characters')
        .update({'role': 'npc'})
        .eq('project_id', world.id)
        .eq('slug', 'slizen');
    final slime = await a
        .from('characters')
        .select('role')
        .eq('project_id', world.id)
        .eq('slug', 'slizen')
        .single();
    expect(slime['role'], 'npc');
  });
}
