// ПОКАЗ, а не проверка (19.10): стрелка у края — связанный объект спрятан за краем полки
// (слева и справа) или за краем холста. В check.sh не входит.
// Запуск: flutter test --no-pub demo/holst_edge_snapshots_test.dart → build/snapshots/edge-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';

Finder token(String slug) => find.byKey(Key('token-$slug'));

void main() {
  testWidgets('стрелки у края полки и холста', (t) async {
    await t.runAsync(loadFont);
    await pumpHolst(
      t,
      await ashMines(),
      wrap: frame,
      size: const Size(360, 760),
    );
    final shelf = find.descendant(
      of: find.byKey(const Key('holst-shelf')),
      matching: find.byType(ListView),
    );

    // Справа: выбран квест, Кирка за правым краем полки.
    await t.tap(token('obval'));
    await shot(t, 'edge-1-right', ratio: 3);

    // Слева: полка прокручена до Кирки, Обвал ушёл за левый край.
    await t.tap(find.byKey(const Key('holst-canvas')));
    await t.pumpAndSettle();
    await t.dragUntilVisible(token('kirka'), shelf, const Offset(-200, 0));
    await t.drag(shelf, const Offset(-200, 0));
    await t.pumpAndSettle();
    await t.tap(token('kirka'));
    await shot(t, 'edge-2-left', ratio: 3);

    // За краем холста: выбран Слизень, холст сдвинут влево — Засада и Слизень за экраном.
    await t.tap(find.byKey(const Key('holst-canvas')));
    await t.pumpAndSettle();
    await t.tap(token('slizen'));
    await t.pumpAndSettle();
    await t.timedDragFrom(
      const Offset(300, 450),
      const Offset(-250, 0),
      const Duration(milliseconds: 400),
    );
    await shot(t, 'edge-3-canvas', ratio: 3);
  });
}
