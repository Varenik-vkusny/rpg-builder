// ПОКАЗ, а не проверка: мир карточками (4½.3) — список, страница локации, персонажа, квеста.
// В check.sh не входит.
// Запуск: flutter test --no-pub demo/design_world_snapshots_test.dart → build/snapshots/4½.3-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('мир карточками: ${b.name}', (t) async {
      await t.runAsync(loadFont);
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.platformBrightnessTestValue = b;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

      await pumpApp(t, content: await minesContent(), wrap: frame);
      await signUp(t, 'author@test.dev');
      await createWorld(t, 'Пепельные копи');
      await openWorld(t, 'Пепельные копи');
      await t.scrollUntilVisible(
        find.byKey(const Key('open-shtolnya_3')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await shot(t, '4½.3-world-${b.name}');

      await tapShown(t, find.byKey(const Key('open-shtolnya_3')));
      await shot(t, '4½.3-location-${b.name}');

      await tapShown(t, find.byKey(const Key('who-slizen')));
      await shot(t, '4½.3-character-${b.name}');
    });
  }
}
