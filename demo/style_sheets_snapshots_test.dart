// ПОКАЗ, а не проверка: все экраны прибора text_fit, 360 dp, шрифт 1.0 — как на телефоне
// владельца. Снимки → build/snapshots/5.2-NN-<экран>.png.
// Запуск: flutter test --no-pub demo/style_sheets_snapshots_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/text_fit.dart';
import '../test/text_fit_test.dart' show exportTour, mainTour;
import 'shots.dart';

void main() {
  for (final (name, tour) in [('a', mainTour), ('b', exportTour)]) {
    testWidgets('все экраны $name', (t) async {
      await t.runAsync(loadFont);
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var n = 0;
      final fit = TextFit('360dp')
        ..frame = frame
        ..shoot = (screen) => shot(
          t,
          '5.2-$name${(n++).toString().padLeft(2, '0')}-'
          '${screen.replaceAll(RegExp(r'[^\wа-яё]+', caseSensitive: false), '_')}',
        );
      fit.start();
      try {
        await tour(t, fit);
      } finally {
        fit.stop();
      }
    });
  }
}
