// ПОКАЗ, а не проверка (19.10): автор выбирает значок вида — окно выбора и жетон со значком.
// В check.sh не входит. Запуск: flutter test --no-pub demo/glyph_pick_snapshots_test.dart
// → build/snapshots/glyph-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  testWidgets('значок вида: выбор и жетон', (t) async {
    await t.runAsync(loadFont);
    await pumpHolst(
      t,
      await ashMines(),
      wrap: frame,
      size: const Size(360, 760),
    );
    Future<void> pick(String slug, String icon) async {
      await t.tap(k('token-$slug'));
      await t.pumpAndSettle();
      await t.tap(k('holst-glyph'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        k('glyph-pick-$icon'),
        200,
        scrollable: find.descendant(
          of: k('glyph-sheet'),
          matching: find.byType(Scrollable),
        ),
      );
      await t.tap(k('glyph-pick-$icon'));
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await t.tap(k('token-slizen'));
    await t.pumpAndSettle();
    await t.tap(k('holst-glyph'));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await shot(t, 'glyph-1-sheet', ratio: 3);
    await t.tap(k('glyph-pick-slime'));
    await t.pumpAndSettle();
    await t.tap(k('token-slizen'));
    await t.pumpAndSettle();
    await pick('brigadir', 'miner');
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
    await shot(t, 'glyph-2-canvas', ratio: 3);
  });
}
