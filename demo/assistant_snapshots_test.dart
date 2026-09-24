// ПОКАЗ, а не проверка: ассистент правок по срезам 3.1–3.6 на подменённой базе
// и подменённом ассистенте. В check.sh не входит.
// Запуск: flutter test --no-pub demo/assistant_snapshots_test.dart → build/snapshots/3.*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('ассистент: штольня №3 затоплена', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = await minesContent();
    final assistant = FakeAssistant([proposal(floodPlan())]);
    await pumpApp(t, content: content, assistant: assistant, wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    // 3.1: область «Штольня №3», просьба → план.
    await tapShown(t, find.byKey(const Key('assistant-open')));
    await pick(t, 'scope-object-location', 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('assistant-request')),
      'Затопи её, слизни там жить не могут',
    );
    await shot(t, '3.1-request');
    await tapShown(t, find.byKey(const Key('assistant-propose')));
    await shot(t, '3.1-plan');
  });
}
