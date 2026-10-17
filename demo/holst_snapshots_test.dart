// ПОКАЗ, а не проверка (5е): холст мира в виде «плашка» на мире как в принятом прототипе.
// В check.sh не входит. Запуск: flutter test --no-pub demo/holst_snapshots_test.dart
// → build/snapshots/holst-*.png (высокое разрешение, ×3).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';

Future<void> hi(WidgetTester t, String name) => shot(t, name, ratio: 3);

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
}
