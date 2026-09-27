// ПОКАЗ, а не проверка: новый экран «План изменений» (4½.2) — светлая и тёмная тема,
// шторка проверки, просмотр по одному. В check.sh не входит.
// Запуск: flutter test --no-pub demo/design_plan_snapshots_test.dart → build/snapshots/4½.2-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('план изменений: ${b.name}', (t) async {
      await t.runAsync(loadFont);
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.platformBrightnessTestValue = b;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

      // Атака утопленника 14 так и остаётся — план с предупреждением.
      final a = FakeAssistant(List.generate(3, (_) => proposal(floodPlan())));
      await pumpApp(
        t,
        content: await minesContent(),
        assistant: a,
        wrap: frame,
      );
      await signUp(t, 'author@test.dev');
      await createWorld(t, 'Пепельные копи');
      await openWorld(t, 'Пепельные копи');
      await tapShown(t, find.byKey(const Key('assistant-open')));
      await pick(t, 'scope-object-location', 'Штольня №3');
      await t.enterText(
        find.byKey(const Key('assistant-request')),
        'Затопи её, слизни там жить не могут',
      );
      await tapShown(t, find.byKey(const Key('assistant-propose')));
      await t.ensureVisible(find.byKey(const Key('plan-summary')));
      await shot(t, '4½.2-plan-${b.name}');

      await tapShown(t, find.byKey(const Key('plan-verdict')));
      await shot(t, '4½.2-check-${b.name}');
      await t.tapAt(const Offset(180, 40));
      await t.pumpAndSettle();

      await tapShown(t, find.byKey(const Key('plan-review')));
      await t.drag(find.byType(PageView), const Offset(-300, 0));
      await shot(t, '4½.2-review-${b.name}');
    });
  }
}
