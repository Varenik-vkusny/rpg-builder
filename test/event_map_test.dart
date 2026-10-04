// События на карте и на странице места (5б.2): на блоке места ⚡ — число своих событий,
// «+N» — событий мест внутри; вместе — столько же, сколько в разделе «События» на странице
// места, где у события вложенного места подписано, где оно идёт;
// проблема события зажигает значок проблемы на блоке его места.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/map/map_model.dart';

import 'fakes.dart';
import 'map_test.dart' show blockLabel, openMap, problemOn;
import 'object_links_test.dart' show open;
import 'place_page_test.dart' show nestedMines, openWorldOf, worldId;

/// Копи › Штольня №3 › Забой и Рынок; «Засада у лебёдки» в штольне (3 слизня),
/// «Обвал кровли» в забое; на рынке событий нет. Слизень — ур. [slimeLevel], места — 1–5.
Future<FakeContent> minesWithEvents({int slimeLevel = 2}) async {
  final c = await nestedMines();
  final places = {for (final l in await c.locations(worldId)) l.slug: l.id};
  final slime = await c.createCharacter(
    worldId,
    NewCharacter(
      title: 'Слизень',
      description: '',
      role: Role.enemy,
      locationId: null,
      level: slimeLevel,
    ),
  );
  await c.createEvent(
    worldId,
    NewEvent(
      title: 'Засада у лебёдки',
      description: '',
      locationId: places['shtolnya_3']!,
      enemies: [EventEnemy(characterId: slime.id, amount: 3)],
    ),
  );
  await c.createEvent(
    worldId,
    NewEvent(
      title: 'Обвал кровли',
      description: '',
      locationId: places['zaboy']!,
    ),
  );
  return c;
}

Finder boltOn(String slug) => find.descendant(
  of: find.byKey(Key('place-$slug')),
  matching: find.byIcon(Symbols.bolt_rounded),
);

Finder textOn(String slug, String text) => find.descendant(
  of: find.byKey(Key('place-$slug')),
  matching: find.text(text),
);

void main() {
  group('блок места: события', () {
    test('свои события и события мест внутри считаются отдельно', () async {
      final w = await (await minesWithEvents()).snapshot(worldId);
      (int, int) events(String slug) {
        final s = placeStats(
          w,
          w.locations.firstWhere((l) => l.slug == slug),
          const [],
        );
        return (s.events, s.eventsInside);
      }

      expect(events('kopi'), (0, 2));
      expect(events('shtolnya_3'), (1, 1));
      expect(events('zaboy'), (1, 0));
      expect(events('rynok'), (0, 0));
    });

    test('проблема события видна на блоке его места и мест выше', () async {
      // Слизень 9-го уровня в сцене в штольне 1–5 — предупреждение на событии.
      final w = await (await minesWithEvents(slimeLevel: 9)).snapshot(worldId);
      final problems = checkWorld(w);
      expect([for (final p in problems) p.rule], ['event_enemy_over_location']);
      Severity? worst(String slug) => placeStats(
        w,
        w.locations.firstWhere((l) => l.slug == slug),
        problems,
      ).worst;
      expect(worst('kopi'), Severity.warning);
      expect(worst('shtolnya_3'), Severity.warning);
      expect(worst('zaboy'), isNull);
      expect(worst('rynok'), isNull);
    });
  });

  testWidgets('карта: ⚡ свои и «+N» внутри; у места без событий ⚡ нет', (t) async {
    final semantics = t.ensureSemantics();
    await openWorldOf(t, await minesWithEvents());
    await openMap(t);

    // Копи: своих событий нет, два — в местах внутри.
    expect(boltOn('kopi'), findsOneWidget);
    expect(textOn('kopi', '0 +2'), findsOneWidget);
    expect(
      blockLabel(t, 'kopi'),
      allOf(contains('событий 0'), contains('событий внутри 2')),
    );
    expect(boltOn('rynok'), findsNothing);
    expect(blockLabel(t, 'rynok'), isNot(contains('событий')));

    // Уровнем ниже: у штольни одно своё и одно в забое; у забоя — только своё, без «+».
    await t.tap(find.byKey(const Key('enter-kopi')));
    await t.pumpAndSettle();
    expect(textOn('shtolnya_3', '1 +1'), findsOneWidget);
    await t.tap(find.byKey(const Key('enter-shtolnya_3')));
    await t.pumpAndSettle();
    expect(boltOn('zaboy'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('place-zaboy')),
        matching: find.textContaining('+'),
      ),
      findsNothing,
    );
    expect(blockLabel(t, 'zaboy'), isNot(contains('событий внутри')));
    semantics.dispose();
  });

  testWidgets('карта: проблема события — значок проблемы на блоке места', (
    t,
  ) async {
    await openWorldOf(t, await minesWithEvents(slimeLevel: 9));
    await openMap(t);
    expect(problemOn('kopi'), findsOneWidget);
    expect(problemOn('rynok'), findsNothing);
  });

  testWidgets('событий на блоке столько же, сколько в разделе «События» на '
      'странице', (t) async {
    // Высокий экран: раздел — третий на странице, за краем он ещё не построен.
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final semantics = t.ensureSemantics();
    await openWorldOf(t, await minesWithEvents());
    await openMap(t);
    final label = blockLabel(t, 'kopi');
    final n =
        int.parse(RegExp(r'событий (\d+)').firstMatch(label)![1]!) +
        int.parse(RegExp(r'событий внутри (\d+)').firstMatch(label)![1]!);
    await t.tap(find.byKey(const Key('place-kopi')));
    await t.pumpAndSettle();
    expect(find.text('События · $n'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('страница места: раздел «События» — свои и вложенных мест; '
      'нажатие открывает событие', (t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await openWorldOf(t, await minesWithEvents());
    await open(t, 'shtolnya_3');

    expect(find.text('События · 2'), findsOneWidget);
    Finder on(String event, Finder what) => find.descendant(
      of: find.byKey(Key('event-$event')),
      matching: what,
    );
    // Своё событие: на карточке — сколько врагов в сцене всего, места не подписано.
    expect(on('zasada_u_lebedki', find.text('3')), findsOneWidget);
    expect(on('zasada_u_lebedki', find.text('Штольня №3')), findsNothing);
    // Событие вложенного места: на карточке подписано, где оно идёт.
    expect(on('obval_krovli', find.text('Забой')), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('event-zasada_u_lebedki')));
    await t.tap(find.byKey(const Key('event-zasada_u_lebedki')));
    await t.pumpAndSettle();
    expect(find.text('Событие'), findsOneWidget);
    expect(find.byKey(const Key('enemy-slizen')), findsOneWidget);
  });

  testWidgets('страница места без событий — раздела «События» нет', (t) async {
    await openWorldOf(t, await minesWithEvents());
    await open(t, 'rynok');
    expect(find.textContaining('События'), findsNothing);
    expect(find.text('Кто здесь · 1'), findsOneWidget);
  });
}
