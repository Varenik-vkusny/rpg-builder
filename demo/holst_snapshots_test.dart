// ПОКАЗ, а не проверка (5е): холст мира в виде «плашка» на мире как в принятом прототипе.
// В check.sh не входит. Запуск: flutter test --no-pub demo/holst_snapshots_test.dart
// → build/snapshots/holst-*.png (высокое разрешение, ×3).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';

Future<void> hi(WidgetTester t, String name, {bool settle = true}) =>
    shot(t, name, ratio: 3, settle: settle);

void main() {
  testWidgets('холст: смотреть', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    await pumpHolst(t, c, wrap: frame);
    await hi(t, 'holst-1-look');

    await t.tap(find.byKey(const Key('token-slizen')));
    await hi(t, 'holst-2-slime');

    await t.tap(find.byKey(const Key('token-obval')));
    await hi(t, 'holst-3-quest');

    await t.tap(find.byKey(const Key('holst-zoom')));
    await hi(t, 'holst-4-far');

    await t.tap(find.byKey(const Key('holst-zoom')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('henter-zaboy')));
    await hi(t, 'holst-5-inside');
  });

  testWidgets('холст: строить — из палитры в место', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    await pumpHolst(t, c, wrap: frame);
    await t.tap(find.byKey(const Key('holst-mode-build')));
    await hi(t, 'holst-6-build');

    final barracks = t.getRect(find.byKey(const Key('hplace-baraki')));
    final from = t.getCenter(find.byKey(const Key('palette-enemy')));
    final to = Offset(barracks.left + 40, barracks.bottom - 20);
    final g = await t.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 10)!);
      await t.pump(const Duration(milliseconds: 16));
    }
    await hi(t, 'holst-7-drag', settle: false);
    await g.up();
    await hi(t, 'holst-8-created', settle: false);
  });
}
