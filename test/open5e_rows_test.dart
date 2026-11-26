// Прибор «справочник Open5e, вид А» (25.11): строка находки — ячейка со значком вида,
// имя, плашки, источник значком; без «System Reference Document» текстом и без английского
// дубля; переключатель «Предметы | Враги» с прямыми углами.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'open5e_enemy_test.dart' show creature;
import 'open5e_russian_test.dart' show enemies, k, search;
import 'open5e_test.dart' show FakeOpen5e, openLibrary, warPick;

void main() {
  testWidgets(
    'предмет: значок вида, плашки, источник значком, без английского',
    (t) async {
      await openLibrary(t, FakeOpen5e([warPick()]));
      final row = k('open5e-srd-2024_war-pick');
      expect(row, findsOneWidget);
      Finder inRow(Finder f) => find.descendant(of: row, matching: f);

      expect(inRow(find.byIcon(Symbols.swords_rounded)), findsOneWidget);
      expect(inRow(find.text('Боевая кирка')), findsOneWidget);
      expect(inRow(find.text('Оружие')), findsOneWidget);
      expect(inRow(find.text('Обычный')), findsOneWidget);
      expect(inRow(find.byKey(const Key('open5e-source'))), findsOneWidget);
      expect(
        inRow(find.textContaining('System Reference')),
        findsNothing,
        reason: 'источник — значком, а не текстом',
      );
      expect(inRow(find.textContaining('War Pick')), findsNothing);
      expect(inRow(find.textContaining('·')), findsNothing);
    },
  );

  testWidgets('враг: череп, опасность и здоровье ячейками, без английского', (
    t,
  ) async {
    final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
    await openLibrary(t, api);
    await enemies(t);
    await search(t, 'skeleton');
    final row = k('open5e-srd_skeleton');
    Finder inRow(Finder f) => find.descendant(of: row, matching: f);

    expect(inRow(find.byIcon(Symbols.skull_rounded)), findsOneWidget);
    expect(inRow(find.byIcon(Symbols.military_tech_rounded)), findsOneWidget);
    expect(inRow(find.byIcon(Symbols.favorite_rounded)), findsOneWidget);
    expect(inRow(find.byKey(const Key('open5e-source'))), findsOneWidget);
    expect(inRow(find.textContaining('System Reference')), findsNothing);
    expect(inRow(find.textContaining('опасность')), findsNothing);
  });

  testWidgets('поле поиска — прямые углы', (t) async {
    await openLibrary(t, FakeOpen5e([warPick()]));
    final theme = Theme.of(t.element(k('open5e-query'))).inputDecorationTheme;
    for (final b in [theme.border, theme.enabledBorder, theme.focusedBorder]) {
      expect((b! as UnderlineInputBorder).borderRadius, BorderRadius.zero);
    }
  });

  testWidgets('переключатель «Предметы | Враги» — прямые углы', (t) async {
    await openLibrary(t, FakeOpen5e([warPick()]));
    final seg = t.widget<SegmentedButton<bool>>(k('open5e-kind'));
    final shape = seg.style!.shape!.resolve({});
    expect(shape, isA<RoundedRectangleBorder>());
    expect((shape as RoundedRectangleBorder).borderRadius, BorderRadius.zero);
    // Углы реально нарисованы прямыми: ни одной скруглённой рамки в переключателе.
    final boxes = find.descendant(
      of: k('open5e-kind'),
      matching: find.byType(DecoratedBox),
    );
    for (final e in boxes.evaluate()) {
      final d = (e.widget as DecoratedBox).decoration;
      if (d is BoxDecoration) {
        expect(d.borderRadius ?? BorderRadius.zero, BorderRadius.zero);
      }
    }
  });
}
