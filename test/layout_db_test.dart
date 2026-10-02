// Раскладка карты в НАСТОЯЩЕЙ базе (5а.4): положение блока сохраняется и читается; чужой автор
// его не видит и не пишет; в историю и откат оно не попадает (VISION §10); удалили место —
// положение ушло с ним.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'change_set_db_test.dart' show draft;
import 'db_helpers.dart';

void main() {
  late SupabaseClient a, b;
  late SupabaseContentRepo repo;
  late World world;
  late Location kopi;

  setUpAll(() async {
    (a, b) = await twoAuthors();
    repo = SupabaseContentRepo(a);
  });

  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Раскладка ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    kopi = await repo.createLocation(
      world.id,
      const NewLocation(
        title: 'Копи',
        description: '',
        levelMin: 1,
        levelMax: 5,
      ),
    );
  });

  tearDown(() => a.from('projects').delete().eq('id', world.id));

  test('положение сохраняется и перезаписывается', () async {
    expect(await repo.layout(world.id), isEmpty);
    await repo.moveLocation(world.id, kopi.id, (x: 120, y: 40));
    await repo.moveLocation(world.id, kopi.id, (x: 300, y: 260));
    expect(await repo.layout(world.id), {kopi.id: (x: 300.0, y: 260.0)});
  });

  test(
    'перенос блока не пишет в историю; откат плана положение не трогает',
    () async {
      await repo.applyChangeSet(
        world.id,
        draft(
          const Plan(
            summary: 'описание копей',
            ops: [
              PlanOp(
                action: OpAction.update,
                type: OpType.location,
                slug: 'kopi',
                fields: {'description': 'затоплены'},
              ),
            ],
          ),
        ),
      );
      await repo.moveLocation(world.id, kopi.id, (x: 80, y: 80));
      final history = await repo.history(world.id);
      expect(history, hasLength(1), reason: 'перенос — не набор изменений');
      await repo.revertChangeSet(world.id, history.first.id);
      expect(await repo.layout(world.id), {kopi.id: (x: 80.0, y: 80.0)});
    },
  );

  test('чужой автор положения не видит и не пишет', () async {
    await repo.moveLocation(world.id, kopi.id, (x: 10, y: 10));
    final other = SupabaseContentRepo(b);
    expect(await other.layout(world.id), isEmpty);
    // Отказ именно правами (RLS, 42501), а не посторонний сбой.
    await expectLater(
      other.moveLocation(world.id, kopi.id, (x: 999, y: 999)),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    expect(await repo.layout(world.id), {kopi.id: (x: 10.0, y: 10.0)});
  });

  test('своё положение для чужого места не пишется', () async {
    // У автора B свой мир и своё место; автор Т кладёт его id в свой мир.
    final theirs = await SupabaseWorldsRepo(b).create(
      const NewWorld(
        title: 'Чужая раскладка',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 5,
      ),
    );
    addTearDown(() => b.from('projects').delete().eq('id', theirs.id));
    final market = await SupabaseContentRepo(b).createLocation(
      theirs.id,
      const NewLocation(
        title: 'Рынок',
        description: '',
        levelMin: 1,
        levelMax: 5,
      ),
    );
    // Место не из этого мира — внешний ключ (23503).
    await expectLater(
      repo.moveLocation(world.id, market.id, (x: 1, y: 1)),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23503')),
    );
    expect(await repo.layout(world.id), isEmpty);
  });

  test('удалили место — положение ушло с ним', () async {
    await repo.moveLocation(world.id, kopi.id, (x: 10, y: 10));
    await a.from('locations').delete().eq('id', kopi.id);
    expect(await repo.layout(world.id), isEmpty);
  });
}
