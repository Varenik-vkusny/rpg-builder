// ПОКАЗ (С10, 22.11): полоса после жеста — «Создано: Житель 1 в Рынке», а не «в «Рынок»».
// В check.sh не входит. Запуск: flutter test --no-pub demo/holst_case_snapshots_test.dart
// → build/snapshots/case-*.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_build_test.dart' show build, drag, placeCenter;
import '../test/holst_fixture.dart';
import 'shots.dart';

void main() {
  testWidgets('полоса после жеста: падеж места', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    await pumpHolst(t, c, size: const Size(360, 780), wrap: frame);
    await build(t);
    await drag(t, 'npc', placeCenter(t, 'rynok'));
    await shot(t, 'case-1-rynok', ratio: 3, settle: false);
    await drag(t, 'enemy', placeCenter(t, 'shtolnya_3'));
    await shot(t, 'case-2-fallback', ratio: 3, settle: false);
  });
}
