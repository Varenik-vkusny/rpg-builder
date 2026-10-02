// Уровни карты (5а.5): «войти» в место — холст уровнем ниже; путь «Карта › Копи › Штольня №3»
// сверху, нажатие на часть пути — туда; «назад» — уровень вверх; пустой уровень — подсказка.
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_test.dart' show openMap, spotOf;
import 'place_page_test.dart' show nestedMines, openWorldOf;

Finder place(String slug) => find.byKey(Key('place-$slug'));

Future<void> enter(WidgetTester t, String slug) async {
  await t.tap(find.byKey(Key('enter-$slug')));
  await t.pumpAndSettle();
}

/// Части пути сверху по порядку.
List<String> crumbs(WidgetTester t) => [
  for (final e in find.byKey(const Key('map-path')).evaluate())
    for (final txt
        in find
            .descendant(
              of: find.byWidget(e.widget),
              matching: find.byType(Text),
            )
            .evaluate())
      (txt.widget as Text).data ?? '',
].where((s) => s != '›').toList();

void main() {
  testWidgets('вход в Копи: на холсте Штольня, путь «Карта › Копи»', (t) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    expect(
      find.byKey(const Key('map-path')),
      findsNothing,
      reason: 'на верхнем уровне пути нет',
    );

    await enter(t, 'kopi');
    expect(place('shtolnya_3'), findsOneWidget);
    expect(place('kopi'), findsNothing);
    expect(place('rynok'), findsNothing);
    expect(place('zaboy'), findsNothing, reason: 'забой — ещё уровнем ниже');
    expect(crumbs(t), ['Карта', 'Копи']);
  });

  testWidgets('Копи › Штольня › Забой: путь ведёт назад на любой уровень', (
    t,
  ) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    await enter(t, 'kopi');
    await enter(t, 'shtolnya_3');
    expect(place('zaboy'), findsOneWidget);
    expect(crumbs(t), ['Карта', 'Копи', 'Штольня №3']);

    await t.tap(find.byKey(const Key('crumb-kopi')));
    await t.pumpAndSettle();
    expect(place('shtolnya_3'), findsOneWidget);
    expect(crumbs(t), ['Карта', 'Копи']);

    await t.tap(find.byKey(const Key('crumb-root')));
    await t.pumpAndSettle();
    expect(place('kopi'), findsOneWidget);
    expect(place('rynok'), findsOneWidget);
  });

  testWidgets('«назад» — уровень вверх; с верхнего — выход из карты', (
    t,
  ) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    await enter(t, 'kopi');
    await enter(t, 'shtolnya_3');

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(place('shtolnya_3'), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(place('kopi'), findsOneWidget);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('map-canvas')), findsNothing);
    expect(find.byKey(const Key('map-open')), findsOneWidget);
  });

  testWidgets('место без вложенных — подсказка, а не пустой холст', (t) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    await enter(t, 'rynok');
    final hint = find.byKey(const Key('map-empty-level'));
    expect(hint, findsOneWidget);
    expect(
      find.descendant(of: hint, matching: find.textContaining('Рынок')),
      findsWidgets,
    );
  });

  testWidgets('кнопка входа — не меньше 48 dp', (t) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    final size = t.getSize(find.byKey(const Key('enter-rynok')));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('Забой — 3-й уровень: подсказка, что глубже не кладут', (
    t,
  ) async {
    await openWorldOf(t, await nestedMines());
    await openMap(t);
    await enter(t, 'kopi');
    await enter(t, 'shtolnya_3');
    await enter(t, 'zaboy');
    final hint = find.byKey(const Key('map-empty-level'));
    expect(
      find.descendant(of: hint, matching: find.textContaining('глубже')),
      findsOneWidget,
    );
  });

  testWidgets(
    'у каждого уровня своя раскладка: перенёс в Копях — там и лежит',
    (t) async {
      await openWorldOf(t, await nestedMines());
      await openMap(t);
      final before = spotOf(t, 'kopi');
      await enter(t, 'kopi');

      final block = find.byKey(const Key('place-shtolnya_3'));
      final g = await t.startGesture(t.getCenter(block));
      await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(10, 25));
        await t.pump();
      }
      await g.up();
      await t.pumpAndSettle();
      final moved = spotOf(t, 'shtolnya_3');

      await t.tap(find.byKey(const Key('crumb-root')));
      await t.pumpAndSettle();
      expect(spotOf(t, 'kopi'), before, reason: 'верхний уровень не сдвинулся');
      await enter(t, 'kopi');
      expect(spotOf(t, 'shtolnya_3'), moved);
      expect(moved.dy, greaterThan(100), reason: 'блок действительно уехал');
    },
  );
}
