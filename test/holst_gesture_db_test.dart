// Жест холста в НАСТОЯЩЕЙ базе (5е, правило 11): каждый вид из палитры создаётся
// правкой вручную — набор в истории, откат возвращает мир как был. Подменённая база
// пишет мир «как скажет приложение»; эта проверка ловит столбцы и ограничения таблиц.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/map/gesture_create.dart';
import 'package:rpg_builder/map/gesture_icon.dart';
import 'package:rpg_builder/map/gesture_link.dart';
import 'package:rpg_builder/map/gesture_move.dart';
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

  test('перенос жестом: житель и событие в другое место, место внутрь места — и откат', () async {
    final w = await repo.snapshot(world.id);
    final shaft = w.locations.firstWhere((l) => l.slug == 'shtolnya_3');
    final market = w.locations.firstWhere((l) => l.slug == 'rynok');
    final ev = createByGesture(world.id, w, NewKind.event, placeId: shaft.id);
    final made = await applyGesture(repo, world.id, w, ev.edit);
    expect(made.applied, isTrue, reason: made.reason);
    var cur = await repo.snapshot(world.id);
    final npc = cur.characters.firstWhere((c) => c.slug == 'brigadir');
    final from = npc.locationId;
    final sets = <String>[];
    Future<void> go(ManualEdit Function(WorldSnapshot) edit) async {
      final r = await applyGesture(repo, world.id, cur, edit(cur));
      expect(r.applied, isTrue, reason: r.reason);
      sets.add(r.setId!);
      cur = await repo.snapshot(world.id);
    }

    final to = from == market.id ? shaft.id : market.id;
    await go((s) => moveObject(world.id, s, npc.id, to));
    await go((s) => moveObject(world.id, s, ev.id, market.id));
    await go((s) => movePlace(world.id, s, market.id, shaft.id));
    expect(cur.characters.firstWhere((c) => c.id == npc.id).locationId, to);
    expect(cur.events.firstWhere((e) => e.id == ev.id).locationId, market.id);
    expect(
      cur.locations.firstWhere((l) => l.id == market.id).parentId,
      shaft.id,
    );
    for (final id in [...sets.reversed, made.setId!]) {
      expect(await undoGesture(repo, world.id, id), isNull);
    }
    final back = await repo.snapshot(world.id);
    expect(back.characters.firstWhere((c) => c.id == npc.id).locationId, from);
    expect(
      back.locations.firstWhere((l) => l.id == market.id).parentId,
      isNull,
    );
    expect(back.events.where((e) => e.id == ev.id), isEmpty);
  });

  test(
    'значок вида: врагу и предмету — в базе, плохое имя — отказ, откат снимает',
    () async {
      var cur = await repo.snapshot(world.id);
      final slime = cur.characters.firstWhere((c) => c.slug == 'slizen');
      final key = cur.items.firstWhere((i) => i.slug == 'klyuch');
      final sets = <String>[];
      for (final (id, icon) in [(slime.id, 'slime'), (key.id, 'key')]) {
        final r = await applyGesture(
          repo,
          world.id,
          cur,
          editIcon(world.id, cur, id, icon)!,
        );
        expect(r.applied, isTrue, reason: r.reason);
        sets.add(r.setId!);
        cur = await repo.snapshot(world.id);
      }
      expect(cur.characters.firstWhere((c) => c.id == slime.id).icon, 'slime');
      expect(cur.items.firstWhere((i) => i.id == key.id).icon, 'key');
      // База сама не пускает имя не из набора по форме: пробелы, заглавные.
      final bad = await applyGesture(
        repo,
        world.id,
        cur,
        editIcon(world.id, cur, slime.id, 'Bad Name')!,
      );
      expect(bad.applied, isFalse);
      for (final id in sets.reversed) {
        expect(await undoGesture(repo, world.id, id), isNull);
      }
      final back = await repo.snapshot(world.id);
      expect(back.characters.firstWhere((c) => c.id == slime.id).icon, isNull);
      expect(back.items.firstWhere((i) => i.id == key.id).icon, isNull);
    },
  );
}
