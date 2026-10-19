// ПОКАЗ, а не проверка (19.10): рамка типа на жетонах — житель круг, враг круг с зубцами,
// предмет квадрат. В check.sh не входит.
// Запуск: flutter test --no-pub demo/token_frame_snapshots_test.dart → build/snapshots/frame-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';

void main() {
  testWidgets('рамки типа на холсте', (t) async {
    await t.runAsync(loadFont);
    await pumpHolst(
      t,
      await ashMines(),
      wrap: frame,
      size: const Size(360, 760),
    );
    await shot(t, 'frame-1-rest', ratio: 3);
    await t.tap(find.byKey(const Key('token-obval')));
    await shot(t, 'frame-2-selected', ratio: 3);
  });
}
