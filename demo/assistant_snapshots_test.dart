// ПОКАЗ, а не проверка: ассистент правок по срезам 3.1–3.6 на подменённой базе
// и подменённом ассистенте. В check.sh не входит.
// Запуск: flutter test --no-pub demo/assistant_snapshots_test.dart → build/snapshots/3.*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';

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
    // Второй ответ — тот же план плюс правка «Рынка», которого в области нет.
    final outside = Plan(
      summary: 'Штольня затоплена, а заодно рынок',
      ops: [
        ...floodPlan().ops,
        const PlanOp(
          action: OpAction.update,
          type: OpType.location,
          slug: 'rynok',
          fields: {'description': 'рынок тоже подтопило'},
        ),
      ],
    );
    final assistant = FakeAssistant([
      proposal(floodPlan()),
      proposal(outside),
    ]);
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

    // 3.2: операция над «Рынком» вне области — приложение её не пускает.
    await tapShown(t, find.byKey(const Key('assistant-propose')));
    await t.scrollUntilVisible(
      find.textContaining('Вне области'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, '3.2-out-of-scope');
  });
}
