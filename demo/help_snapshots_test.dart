// ПОКАЗ, а не проверка: справка «?» (5а+) — форма врага и план, шторки. В check.sh не входит.
// Запуск: flutter test --no-pub demo/help_snapshots_test.dart → build/snapshots/help-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('справка: форма врага, «Шанс», «Роль», план', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

    final a = FakeAssistant(List.generate(3, (_) => proposal(floodPlan())));
    await pumpApp(t, content: await minesContent(), assistant: a, wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await t.scrollUntilVisible(
      find.byKey(const Key('open-slizen')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapShown(t, find.byKey(const Key('open-slizen')));
    await tapShown(t, find.byKey(const Key('object-edit')));
    await shot(t, 'help-1-form');
    await tapShown(t, find.byKey(const Key('help-loot.chance')));
    await shot(t, 'help-2-chance');
    await t.tapAt(const Offset(180, 40));
    await t.pumpAndSettle();
    await tapShown(t, find.byKey(const Key('help-character.role')));
    await shot(t, 'help-3-role');
    await t.tapAt(const Offset(180, 40));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();

    // Срез 2: остальные формы.
    for (final (slug, name) in [
      ('shtolnya_3', 'place'),
      ('klyuch', 'item'),
      ('obval', 'quest'),
    ]) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(Key('open-$slug')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapShown(t, find.byKey(Key('open-$slug')));
      await tapShown(t, find.byKey(const Key('object-edit')));
      await shot(t, 'help-form-$name');
      await t.pageBack();
      await t.pumpAndSettle();
      await t.pageBack();
      await t.pumpAndSettle();
    }

    await tapShown(t, find.byKey(const Key('assistant-open')));
    await shot(t, 'help-form-request');
    await tapShown(t, find.byKey(const Key('help-assistant.scope.object')));
    await shot(t, 'help-form-request-sheet');
    await t.tapAt(const Offset(180, 40));
    await t.pumpAndSettle();
    await pick(t, 'scope-object-location', 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('assistant-request')),
      'Затопи её, слизни там жить не могут',
    );
    await tapShown(t, find.byKey(const Key('assistant-propose')));
    await t.ensureVisible(find.byKey(const Key('plan-summary')));
    await shot(t, 'help-4-plan');
    await tapShown(t, find.byKey(const Key('help-screen-plan')));
    await shot(t, 'help-5-plan-sheet');
  });

  testWidgets('справка экранов: мир, карта, проверка', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

    await pumpApp(t, content: await minesContent(), wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await shot(t, 'help-screen-world');
    await tapShown(t, find.byKey(const Key('help-screen-world')));
    await shot(t, 'help-screen-world-sheet');
    await t.tapAt(const Offset(180, 40));
    await t.pumpAndSettle();

    await tapShown(t, find.byKey(const Key('map-open')));
    await tapShown(t, find.byKey(const Key('help-screen-map')));
    await shot(t, 'help-screen-map-sheet');
    await t.tapAt(const Offset(180, 40));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();

    await tapShown(t, find.byKey(const Key('check-world')));
    await tapShown(t, find.byKey(const Key('help-screen-check')));
    await shot(t, 'help-screen-check-sheet');
  });
}
