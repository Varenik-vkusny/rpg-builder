// ПОКАЗ, а не проверка: ассистент создаёт и меняет событие (Ступень 2) на подменённой модели.
// В check.sh не входит. Запуск: flutter test --no-pub demo/event_plan_snapshots_test.dart
// → build/snapshots/s2-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_event_ops_test.dart' show createPlan, updatePlan;
import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

Future<void> openMines(
  WidgetTester t,
  FakeAssistant a, {
  bool event = false,
}) async {
  await t.runAsync(loadFont);
  t.view.physicalSize = const Size(400, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final content = await minesContent();
  if (event) await addAmbush(content, minesId);
  await pumpApp(t, content: content, assistant: a, wrap: frame);
  await signUp(t, 'author@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  await tapShown(t, find.byKey(const Key('assistant-open')));
  await pick(t, 'scope-object-location', 'Штольня №3');
  await t.enterText(
    find.byKey(const Key('assistant-request')),
    'добавь засаду',
  );
  await tapShown(t, find.byKey(const Key('assistant-propose')));
}

void main() {
  testWidgets('ассистент создаёт событие: план → история', (t) async {
    await openMines(t, FakeAssistant([proposal(createPlan)]));
    await shot(t, 's2-1-plan-create');
    await tapShown(t, find.byKey(const Key('plan-apply')));
    await tapShown(t, find.byKey(const Key('history-open')));
    await tapShown(t, find.text(createPlan.summary));
    await shot(t, 's2-2-history-create');
  });

  testWidgets('ассистент меняет событие: × 3 → × 5, ключ убран', (t) async {
    await openMines(t, FakeAssistant([proposal(updatePlan)]), event: true);
    await shot(t, 's2-3-plan-update');
  });
}
