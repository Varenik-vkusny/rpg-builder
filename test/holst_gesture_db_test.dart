// Жест холста в НАСТОЯЩЕЙ базе (5е, правило 11): каждый вид из палитры создаётся
// правкой вручную — набор в истории, откат возвращает мир как был. Подменённая база
// пишет мир «как скажет приложение»; эта проверка ловит столбцы и ограничения таблиц.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/map/gesture_create.dart';
import 'package:rpg_builder/map/gesture_path.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'db_helpers.dart';

void main() {
  late SupabaseClient a;
  late World world;
  late SupabaseContentRepo repo;

  setUpAll(() async {
    a = await testAuthor();
    repo = SupabaseContentRepo(a);
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Холст ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    await fillMines(repo, world.id);
  });

  tearDownAll(() => a.from('projects').delete().eq('id', world.id));

  for (final kind in NewKind.values) {
    test('жест «${newTitle(kind)}»: в базе, в истории, откат — как было', () async {
      final w = await repo.snapshot(world.id);
      final place = w.locations.first;
      final made = createByGesture(
        world.id,
        w,
        kind,
        placeId: kind == NewKind.item ? null : place.id,
        levels: (place.levelMin, place.levelMax),
      );
      final r = await applyGesture(repo, world.id, w, made.edit);
      expect(r.applied, isTrue, reason: r.reason);
      final after = await repo.snapshot(world.id);
      final ids = {
        ...after.locations.map((x) => x.id),
        ...after.characters.map((x) => x.id),
        ...after.events.map((x) => x.id),
        ...after.items.map((x) => x.id),
      };
      expect(ids, contains(made.id));
      expect(
        (await repo.history(world.id)).first.request,
        'Холст: создано «${newTitle(kind)}»',
      );
      expect(await undoGesture(repo, world.id, r.setId!), isNull);
      final back = await repo.snapshot(world.id);
      expect(back.locations.length, w.locations.length);
      expect(back.characters.length, w.characters.length);
      expect(back.events.length, w.events.length);
      expect(back.items.length, w.items.length);
    });
  }
}
