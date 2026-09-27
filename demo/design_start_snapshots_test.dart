// ПОКАЗ, а не проверка: вход, список миров, обзор мира и формы (4½.5) на 360 dp.
// В check.sh не входит.
// Запуск: flutter test --no-pub demo/design_start_snapshots_test.dart → build/snapshots/4½.5-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('вход, миры, обзор, формы: ${b.name}', (t) async {
      await t.runAsync(loadFont);
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.platformBrightnessTestValue = b;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(t, content: await minesContent(), wrap: frame);
      await shot(t, '4½.5-auth-${b.name}');
      await signUp(t, 'author@test.dev');
      await shot(t, '4½.5-worlds-empty-${b.name}');
      await createWorld(t, 'Пепельные копи');
      await shot(t, '4½.5-worlds-${b.name}');
      await openWorld(t, 'Пепельные копи');
      await shot(t, '4½.5-overview-${b.name}');

      await t.scrollUntilVisible(
        find.byKey(const Key('new-character')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tapShown(t, find.byKey(const Key('new-character')));
      await shot(t, '4½.5-form-character-${b.name}');
      await t.pageBack();
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('new-quest')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tapShown(t, find.byKey(const Key('new-quest')));
      await shot(t, '4½.5-form-quest-${b.name}');
    });
  }
}
