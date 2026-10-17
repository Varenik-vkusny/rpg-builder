// Жест холста в НАСТОЯЩЕЙ базе (5е, правило 11): каждый вид из палитры создаётся
// правкой вручную — набор в истории, откат возвращает мир как был. Подменённая база
// пишет мир «как скажет приложение»; эта проверка ловит столбцы и ограничения таблиц.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/map/gesture_create.dart';
import 'package:rpg_builder/map/gesture_link.dart';
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
    test(
      'жест «${newTitle(kind)}»: в базе, в истории, откат — как было',
      () async {
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
      },
    );
  }

  test('связи жестом: добыча, все 4 вида шага квеста, враг и предмет события — и откат', () async {
    // Свежие враг, житель и событие — чтобы ни одна связь не существовала заранее.
    final made = <String>[];
    Future<String> fresh(NewKind kind) async {
      final w = await repo.snapshot(world.id);
      final m = createByGesture(
        world.id,
        w,
        kind,
        placeId: w.locations.first.id,
      );
      final r = await applyGesture(repo, world.id, w, m.edit);
      expect(r.applied, isTrue, reason: '$kind: ${r.reason}');
      made.add(r.setId!);
      return m.id;
    }

    final enemy = await fresh(NewKind.enemy);
    final npc = await fresh(NewKind.npc);
    final ev = await fresh(NewKind.event);
    final w0 = await repo.snapshot(world.id);
    final pick = w0.items.firstWhere((i) => i.slug == 'kirka').id;
    final quest = w0.quests.first.id;
    final steps = w0.quests.first.steps.length;
    final links = [
      (LinkKind.loot, enemy, pick, 40),
      (LinkKind.talk, quest, npc, 1),
      (LinkKind.kill, quest, enemy, 2),
      (LinkKind.collect, quest, pick, 2),
      (LinkKind.pass, quest, ev, 1),
      (LinkKind.eventEnemy, ev, enemy, 3),
      (LinkKind.eventItem, ev, pick, 1),
    ];
    final setIds = <String>[];
    for (final (kind, from, to, v) in links) {
      final cur = await repo.snapshot(world.id);
      expect(linked(cur, kind, from, to), isFalse, reason: '$kind уже есть');
      final r = await applyGesture(
        repo,
        world.id,
        cur,
        linkByGesture(world.id, cur, kind, from, to, v),
      );
      expect(r.applied, isTrue, reason: '$kind: ${r.reason}');
      setIds.add(r.setId!);
      expect(
        linked(await repo.snapshot(world.id), kind, from, to),
        isTrue,
        reason: '$kind',
      );
    }
    final now = await repo.snapshot(world.id);
    expect(now.quests.first.steps, hasLength(steps + 4));
    expect(
      now.characters.firstWhere((c) => c.id == enemy).loot.single.chance,
      40,
    );
    final e = now.events.firstWhere((x) => x.id == ev);
    expect(e.enemies.single.amount, 3);
    expect(e.itemIds.single, pick);
    for (final id in [...setIds.reversed, ...made.reversed]) {
      expect(await undoGesture(repo, world.id, id), isNull);
    }
    final back = await repo.snapshot(world.id);
    expect(back.quests.first.steps, hasLength(steps));
    expect(back.events.where((x) => x.id == ev), isEmpty);
    expect(back.characters.where((x) => x.id == enemy || x.id == npc), isEmpty);
  });
}
