// Карта-холст (5а.3): открывается кнопкой из мира; места верхнего уровня — блоки с числом
// жителей, вложенных и значком проблемы; нажатие открывает страницу места; блок ≥ 48 dp;
// пустой мир — подсказка, а не пустой экран.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/map/map_model.dart';

import 'fakes.dart';
import 'place_page_test.dart' show nestedMines, openWorldOf, worldId;

Future<void> openMap(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('map-open')));
  await t.tap(find.byKey(const Key('map-open')));
  await t.pumpAndSettle();
}

String blockLabel(WidgetTester t, String slug) =>
    t.getSemantics(find.byKey(Key('place-$slug'))).label;

/// Копи с вложенными и Рынок, где враг сильнее потолка уровня — предупреждение.
Future<FakeContent> minesWithProblem() async {
  final c = await nestedMines();
  final market = (await c.locations(worldId))
      .firstWhere((l) => l.slug == 'rynok');
  await c.createCharacter(
    worldId,
    NewCharacter(
      title: 'Пепельный голем',
      description: '',
      role: Role.enemy,
      locationId: market.id,
      level: 2,
      attack: 30,
    ),
  );
  return c;
}

Finder problemOn(String slug) => find.descendant(
  of: find.byKey(Key('place-$slug')),
  matching: find.byKey(const Key('problem-cell')),
);

void main() {
  testWidgets('значок проблемы — только на блоке с проблемой', (t) async {
    await openWorldOf(t, await minesWithProblem());
    await openMap(t);
    expect(problemOn('rynok'), findsOneWidget);
    expect(problemOn('kopi'), findsNothing);
  });

  testWidgets('жителей на блоке столько же, сколько «Кто здесь» на странице', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await openWorldOf(t, await minesWithProblem());
    await openMap(t);
    for (final slug in ['kopi', 'rynok']) {
      final n = RegExp(r'жителей (\d+)').firstMatch(blockLabel(t, slug))![1];
      await t.tap(find.byKey(Key('place-$slug')));
      await t.pumpAndSettle();
      expect(find.text('Кто здесь · $n'), findsOneWidget, reason: slug);
      await t.pageBack();
      await t.pumpAndSettle();
    }
    semantics.dispose();
  });

  testWidgets('карта: верхний уровень — блоки, вложенные внутри не видны', (
    t,
  ) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);

    expect(find.byKey(const Key('place-kopi')), findsOneWidget);
    expect(find.byKey(const Key('place-rynok')), findsOneWidget);
    // Штольня и забой — внутри копей, на этом уровне их нет.
    expect(find.byKey(const Key('place-shtolnya_3')), findsNothing);
    expect(find.byKey(const Key('place-zaboy')), findsNothing);
  });

  testWidgets('блок копей: 3 жителя по глубине, 1 вложенное место', (t) async {
    final semantics = t.ensureSemantics();
    await openWorldOf(t, await nestedMines());
    await openMap(t);

    expect(
      blockLabel(t, 'kopi'),
      allOf(contains('Копи'), contains('жителей 3'), contains('внутри 1')),
    );
    expect(
      blockLabel(t, 'rynok'),
      allOf(contains('жителей 1'), isNot(contains('внутри'))),
    );
    semantics.dispose();
  });

  testWidgets('нажатие на блок открывает страницу места', (t) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    await t.tap(find.byKey(const Key('place-kopi')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('inner-shtolnya_3')), findsOneWidget);
  });

  testWidgets('блок не меньше 48 dp — по нему легко попасть', (t) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    final size = t.getSize(find.byKey(const Key('place-rynok')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('мир без мест — подсказка, а не пустой холст', (t) async {
    await openWorldOf(t, FakeContent());
    await openMap(t);
    expect(find.byKey(const Key('map-empty')), findsOneWidget);
  });

  group('счёт блока', () {
    Location place(String id, [String? parent]) => Location(
      id: id,
      slug: id,
      title: id,
      description: '',
      levelMin: 1,
      levelMax: 5,
      parentId: parent,
    );

    test('проблема жителя вложенного места видна на блоке родителя', () {
      final w = WorldSnapshot(
        locations: [place('a'), place('b', 'a')],
        characters: const [
          Character(
            id: 'slime',
            slug: 'slime',
            title: 'Слизень',
            description: '',
            role: Role.enemy,
            locationId: 'b',
            loot: [],
          ),
        ],
      );
      final s = placeStats(w, w.locations.first, const [
        Problem(Severity.warning, 'x', 'slime', 'm'),
      ]);
      expect(s.worst, Severity.warning);
      expect(s.problems, 1);
      expect(s.residents, 1);
      expect(s.inner, 1);
    });

    test('ошибка важнее предупреждения', () {
      final w = WorldSnapshot(locations: [place('a')]);
      final s = placeStats(w, w.locations.first, const [
        Problem(Severity.warning, 'x', 'a', 'm'),
        Problem(Severity.error, 'y', 'a', 'm'),
      ]);
      expect(s.worst, Severity.error);
      expect(s.problems, 2);
    });

    test('автораскладка: блоки не налезают друг на друга', () {
      final spots = autoLayout(7);
      for (var i = 0; i < spots.length; i++) {
        for (var j = i + 1; j < spots.length; j++) {
          expect(
            (spots[i] & blockSize).overlaps(spots[j] & blockSize),
            isFalse,
            reason: '$i и $j',
          );
        }
      }
    });
  });
}
