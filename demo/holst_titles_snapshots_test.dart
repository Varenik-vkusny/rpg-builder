// ПОКАЗ (С5, 22.11): враги из палитры — «Враг 1», «Враг 2», а не одинаковые «Новый враг».
// В check.sh не входит. Запуск: flutter test --no-pub demo/holst_titles_snapshots_test.dart
// → build/snapshots/titles-*.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_build_test.dart' show build, drag, placeCenter;
import '../test/holst_fixture.dart';
import 'shots.dart';

void main() {
  testWidgets('два врага и житель из палитры — разные имена', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    await pumpHolst(t, c, size: const Size(360, 780), wrap: frame);
    await build(t);
    await drag(t, 'enemy', placeCenter(t, 'baraki'));
    await drag(t, 'enemy', placeCenter(t, 'baraki'));
    await drag(t, 'npc', placeCenter(t, 'rynok'));
    await shot(t, 'titles-1-numbered', ratio: 3, settle: false);
  });
}
