// ПОКАЗ, а не проверка (20.11): место до и после «Применить» плана — старые жетоны
// на своих клетках. В check.sh не входит. Запуск: flutter test --no-pub
// demo/holst_cells_snapshots_test.dart → build/snapshots/cells-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart' show addAmbush, floodPlan;
import '../test/holst_build_test.dart' show settle;
import '../test/holst_change_test.dart' show ask, everyTry, k, mines;
import '../test/holst_fixture.dart';
import 'shots.dart';

void main() {
  testWidgets('место до и после применения плана', (t) async {
    await t.runAsync(loadFont);
    final c = await mines();
    await addAmbush(c, holstWorld.id);
    await pumpHolst(
      t,
      c,
      wrap: frame,
      size: const Size(380, 700),
      assistant: everyTry(floodPlan()),
    );
    await shot(t, 'cells-1-before', ratio: 2);
    await ask(t);
    await t.pump(const Duration(seconds: 4));
    await t.tap(k('holst-plan-apply'));
    await settle(t);
    await shot(t, 'cells-2-after', ratio: 2);
  });
}
