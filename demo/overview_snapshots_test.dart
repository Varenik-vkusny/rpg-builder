// ПОКАЗ, а не проверка: обзор мира (4.2) и фильтры (4.3) на подменённой базе.
// Запуск: flutter test --no-pub demo/overview_snapshots_test.dart → build/snapshots/4.2-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/autofix_test.dart' show floodWithAttack;
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('обзор мира после затопления', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await pumpApp(
      t,
      content: await minesContent(),
      assistant: FakeAssistant([
        for (var i = 0; i < 3; i++) proposal(floodWithAttack(14)),
      ]),
      wrap: frame,
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await shot(t, '4.2-overview-empty');

    // Затопление с атакой 14 (предупреждение) применено — обзор это показывает.
    await tapShown(t, find.byKey(const Key('assistant-open')));
    await pick(t, 'scope-object-location', 'Штольня №3');
    await t.enterText(find.byKey(const Key('assistant-request')), 'Затопи её');
    await tapShown(t, find.byKey(const Key('assistant-propose')));
    await tapShown(t, find.byKey(const Key('plan-apply')));
    await shot(t, '4.2-overview');
  });
}
