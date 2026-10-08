// ПОКАЗ, а не проверка: вопрос перед удалением и перед откатом. В check.sh не входит.
// Запуск: flutter test --no-pub demo/messages_snapshots_test.dart → build/snapshots/msg-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/apply_flow_test.dart' show tapButton;
import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

Future<FakeContent> openMines(WidgetTester t) async {
  await t.runAsync(loadFont);
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final content = await minesContent();
  await pumpApp(t, content: content, assistant: FakeAssistant(), wrap: frame);
  await signUp(t, 'author@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  return content;
}

void main() {
  testWidgets('вопрос перед удалением места и перед откатом', (t) async {
    await openMines(t);
    await tapButton(t, 'open-rynok');
    await tapButton(t, 'object-edit');
    await tapButton(t, 'object-delete');
    await shot(t, 'msg-1-delete-question');
    await tapButton(t, 'confirm-yes');

    await tapButton(t, 'history-open');
    await t.tap(find.text('Удаление вручную: Рынок'));
    await t.pumpAndSettle();
    await tapButton(t, 'revert-set-0');
    await shot(t, 'msg-2-revert-question');
  });
}
