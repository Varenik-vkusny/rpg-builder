// ПОКАЗ, а не проверка: «Попросить ассистента исправить» с экрана «Проверка мира» (3.8).
// Запуск: flutter test --no-pub demo/check_fix_snapshots_test.dart → build/snapshots/3.8-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/check_fix_test.dart' show calmMole, fixFor, troubled;
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('проверка → исправить → план → применить', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = await troubled();
    await pumpApp(
      t,
      content: content,
      assistant: FakeAssistant([proposal(calmMole)]),
      wrap: frame,
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await tapShown(t, find.byKey(const Key('check-world')));
    await shot(t, '3.8-check');

    await tapShown(t, fixFor('Бешеный крот'));
    await shot(t, '3.8-assistant-prefilled');
    await tapShown(t, find.byKey(const Key('assistant-propose')));
    await shot(t, '3.8-plan');
    await tapShown(t, find.byKey(const Key('plan-apply')));
    await shot(t, '3.8-check-after');
  });
}
