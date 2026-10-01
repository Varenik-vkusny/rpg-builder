// Вложенность мест в НАСТОЯЩЕЙ базе (5а.1): база сама не пускает четвёртый уровень,
// место в самом себе и удаление места с вложенными; план с родителем применяется
// и откатывается, ручная правка родителя — тоже.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/content/nesting.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'change_set_db_test.dart' show draft;
import 'db_helpers.dart';

/// Отказ базы с этим текстом — а не посторонний сбой.
Matcher nesting(String text) => isA<PostgrestException>().having(
  (e) => e.message,
  'message',
  contains(text),
);

void main() {
  late SupabaseClient a;
  late World world;
  late SupabaseContentRepo repo;
  late Location kopi, shtolnya, zaboy;

  setUpAll(() async {
    a = await testAuthor();
    repo = SupabaseContentRepo(a);
  });

  Future<Location> add(String title, [Location? parent]) => repo.createLocation(
    world.id,
    NewLocation(
      title: title,
      description: '',
      levelMin: 1,
      levelMax: 5,
      parentId: parent?.id,
    ),
  );

  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Вложенность ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    kopi = await add('Копи');
    shtolnya = await add('Штольня №3', kopi);
    zaboy = await add('Забой', shtolnya);
  });

  // Мир с вложенными местами удаляется целиком — каскад не упирается во внешний ключ.
  tearDown(() async {
    await a.from('projects').delete().eq('id', world.id);
    expect(
      await a.from('locations').select('id').eq('project_id', world.id),
      isEmpty,
    );
  });

  Future<List<String>> paths() async {
    final ls = await repo.locations(world.id);
    return [for (final l in ls) pathOf(ls, l)];
  }

  test('три уровня записываются; путь читается из базы', () async {
    expect(
      await paths(),
      unorderedEquals([
        'Копи',
        'Копи › Штольня №3',
        'Копи › Штольня №3 › Забой',
      ]),
    );
  });

  test('четвёртый уровень база не пускает', () async {
    await expectLater(
      add('Дно', zaboy),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('глубже 3 уровней'),
        ),
      ),
    );
    // И переносом: Копи с тремя уровнями внутри в «Рынок» — четыре.
    final rynok = await add('Рынок');
    await expectLater(
      a.from('locations').update({'parent_id': rynok.id}).eq('id', kopi.id),
      throwsA(nesting('глубже 3 уровней')),
    );
  });

  test('место в самом себе база не пускает', () async {
    await expectLater(
      a.from('locations').update({'parent_id': kopi.id}).eq('id', kopi.id),
      throwsA(nesting('locations_parent_not_self')),
    );
    await expectLater(
      a.from('locations').update({'parent_id': zaboy.id}).eq('id', kopi.id),
      throwsA(nesting('лежит само в себе')),
    );
  });

  test('удалить место с вложенными база не даёт', () async {
    await expectLater(
      a.from('locations').delete().eq('id', shtolnya.id),
      throwsA(nesting('locations_parent_fk')),
    );
    expect((await paths()).length, 3);
  });

  test('план кладёт новое место внутрь; откат убирает его', () async {
    await repo.applyChangeSet(
      world.id,
      draft(
        const Plan(
          summary: 'колодец в штольне',
          ops: [
            PlanOp(
              action: OpAction.create,
              type: OpType.location,
              slug: 'kolodec',
              fields: {
                'title': 'Колодец',
                'level_min': 2,
                'level_max': 3,
                'parent': 'shtolnya_3',
              },
            ),
          ],
        ),
      ),
    );
    expect(await paths(), contains('Копи › Штольня №3 › Колодец'));
    await repo.revertChangeSet(
      world.id,
      (await repo.history(world.id)).first.id,
    );
    expect((await paths()).length, 3);
  });

  test('ручная правка: забой на верхний уровень, откат — обратно', () async {
    await repo.applyManualEdit(
      world.id,
      editLocation(
        world.id,
        zaboy,
        const NewLocation(
          title: 'Забой',
          description: '',
          levelMin: 1,
          levelMax: 5,
        ),
      ),
    );
    expect(await paths(), contains('Забой'));
    await repo.revertChangeSet(
      world.id,
      (await repo.history(world.id)).first.id,
    );
    expect(await paths(), contains('Копи › Штольня №3 › Забой'));
  });
}
