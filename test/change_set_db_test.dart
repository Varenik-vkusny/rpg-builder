// «Применить» и «Отклонить» в НАСТОЯЩЕЙ базе (3.5–3.6): одна транзакция,
// журнал с «было» и «стало», токены и попытки, чужой мир недоступен.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'autofix_test.dart' show floodWithAttack;
import 'db_helpers.dart';

ChangeSetDraft draft(Plan plan, {int attempts = 2}) => ChangeSetDraft(
  scope: const Scope(ScopeType.location, 'shtolnya_3'),
  request: 'затопи её, слизни там жить не могут',
  plan: plan,
  inputTokens: 2000,
  outputTokens: 400,
  attempts: attempts,
);

/// Мир строками по алфавиту: всё, что может поменять план. Порядок чтения
/// из базы у объектов, созданных в один миг, не гарантирован.
List<String> dump(WorldSnapshot w) {
  final t = w.titles;
  return [
    for (final l in w.locations) '${l.slug}:${l.description}',
    for (final c in w.characters)
      '${c.slug}:${t[c.locationId]}:${c.attack}:'
          '${c.loot.map((l) => '${t[l.itemId]}${l.chanceLabel}')}',
    for (final q in w.quests)
      '${q.slug}:${q.steps.map((s) => '${t[s.targetId]}×${s.amount}')}',
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

  // Свежий мир на каждый тест: план его меняет.
  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Наборы ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    await fillMines(repo, world.id);
  });

  tearDown(() => a.from('projects').delete().eq('id', world.id));

  Future<List<Map<String, dynamic>>> sets() =>
      a.from('change_sets').select().eq('project_id', world.id);

  test('применить: план затопления записан в мир целиком', () async {
    await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
    final w = await repo.snapshot(world.id);
    expect(
      dump(w),
      [
        'shtolnya_3:затоплена по пояс',
        'rynok:',
        'brigadir:null:0:()',
        'slizen:Штольня №3:5:()',
        'utoplennik:Штольня №3:8:(Ключ35%)',
        'obval:(Бригадир×null, Утопленник×3, Ключ×1)',
      ]..sort(),
    );
  });

  test(
    'применить: журнал — операции с «было» и «стало», токены, попытки',
    () async {
      await repo.applyChangeSet(world.id, draft(floodWithAttack(8)));
      final set = (await sets()).single;
      expect(set['status'], 'applied');
      expect(set['scope_slug'], 'shtolnya_3');
      final ops = await a
          .from('change_ops')
          .select()
          .eq('change_set_id', set['id'])
          .order('position', ascending: true);
      expect(
        ops.map(
          (o) => '${o['action']} ${o['object_type']} ${o['object_slug']}',
        ),
        [
          'update location shtolnya_3',
          'create character utoplennik',
          'delete loot slizen/klyuch',
          'create loot utoplennik/klyuch',
          'update quest_step obval#2',
        ],
      );
      expect(ops[0]['before']['description'], 'обвалившаяся выработка');
      expect(ops[0]['after']['description'], 'затоплена по пояс');
      expect((ops[1]['before'], ops[1]['after']['attack']), (null, 8));
      expect((ops[2]['before']['chance'], ops[2]['after']), (35, null));
      final gen = await a
          .from('generations')
          .select()
          .eq('change_set_id', set['id'])
          .single();
      expect(
        (gen['input_tokens'], gen['output_tokens'], gen['attempts']),
        (2000, 400, 2),
      );
    },
  );

  test(
    'применить: ошибка в последней операции — не записано ничего (транзакция)',
    () async {
      final before = dump(await repo.snapshot(world.id));
      final plan = floodWithAttack(8);
      final broken = Plan(
        summary: plan.summary,
        ops: [
          ...plan.ops,
          const PlanOp(
            action: OpAction.update,
            type: OpType.loot,
            character: 'utoplennik',
            item: 'klyuch',
            fields: {'chance': 150},
          ),
        ],
      );
      await expectLater(
        repo.applyChangeSet(world.id, draft(broken)),
        throwsA(isA<PostgrestException>()),
      );
      expect(dump(await repo.snapshot(world.id)), before);
      expect(await sets(), isEmpty);
    },
  );

  test(
    'применить: больше трёх попыток (2 исправления) база не примет',
    () async {
      final before = dump(await repo.snapshot(world.id));
      await expectLater(
        repo.applyChangeSet(world.id, draft(floodWithAttack(8), attempts: 4)),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
        ),
      );
      expect(dump(await repo.snapshot(world.id)), before);
    },
  );

  test('применить: чужой автор не применит план к чужому миру', () async {
    final before = dump(await repo.snapshot(world.id));
    await expectLater(
      SupabaseContentRepo(b)
          .applyChangeSet(world.id, draft(floodWithAttack(8))),
      throwsA(isA<PostgrestException>()),
    );
    expect(dump(await repo.snapshot(world.id)), before);
    expect(await sets(), isEmpty);
  });

  test(
    'отклонить: мир не изменился, набор записан со статусом rejected',
    () async {
      final before = dump(await repo.snapshot(world.id));
      await repo.rejectChangeSet(world.id, draft(floodWithAttack(8)));
      expect(dump(await repo.snapshot(world.id)), before);
      final set = (await sets()).single;
      expect(set['status'], 'rejected');
      final ops = await a
          .from('change_ops')
          .select()
          .eq('change_set_id', set['id']);
      expect(ops.length, 5);
      expect(
        ops.every((o) => o['before'] == null && o['after'] == null),
        isTrue,
      );
      final gen = await a
          .from('generations')
          .select()
          .eq('change_set_id', set['id'])
          .single();
      expect(gen['attempts'], 2);
    },
  );
}
