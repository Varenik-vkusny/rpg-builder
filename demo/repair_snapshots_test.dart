// ПОКАЗ, а не проверка: сервер поправил план до проверки (срез А2) — пометки у операций.
// В check.sh не входит. Запуск: flutter test --no-pub demo/repair_snapshots_test.dart
// → build/snapshots/A2-repairs.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('ассистент: сервер поправил опечатку и порядок', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    // Так план приходит с сервера: создание утопленника перенесено вперёд,
    // опечатка в slug слизня исправлена (repair.ts).
    final j = floodPlanJson();
    final ops = j['ops'] as List;
    (ops[1]['fields'] as Map)['attack'] = 8;
    ops[1]['repairs'] = ['порядок: была операция 4, стала 2'];
    ops[2]['repairs'] = ['опечатка в slug: slizn → slizen'];
    final assistant = FakeAssistant([proposal(Plan.fromJson(j))]);
    await pumpApp(t, content: await minesContent(), assistant: assistant, wrap: frame);
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
    await t.scrollUntilVisible(
      find.byKey(const Key('plan-op-2')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await shot(t, 'A2-repairs');
  });
}
