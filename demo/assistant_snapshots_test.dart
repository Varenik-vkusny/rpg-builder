// ПОКАЗ, а не проверка: ассистент правок по срезам 3.1–3.6 на подменённой базе
// и подменённом ассистенте. В check.sh не входит.
// Запуск: flutter test --no-pub demo/assistant_snapshots_test.dart → build/snapshots/3.*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';

import '../test/assistant_fixtures.dart';
import '../test/autofix_test.dart' show floodWithAttack;
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('ассистент: штольня №3 затоплена', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = await minesContent();
    // Повторная просьба — правка «Рынка», которого в области штольни нет.
    final outside = Plan(
      summary: 'Рынок тоже подтопило',
      ops: [
        const PlanOp(
          action: OpAction.update,
          type: OpType.location,
          slug: 'rynok',
          fields: {'description': 'рынок тоже подтопило'},
        ),
      ],
    );
    // Первый план — атака утопленника 14, исправление — 8 (как в сцене защиты).
    final assistant = FakeAssistant([
      proposal(floodWithAttack(14)),
      proposal(floodWithAttack(8)),
      for (var i = 0; i < 3; i++) proposal(outside),
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
    await shot(t, '3.1-plan'); // уже после автоисправления 3.4

    // 3.3: план на копии — итог проверки и «было → стало» по операциям.
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(
      find.byKey(const Key('plan-op-4')),
      200,
      scrollable: list,
    );
    await shot(t, '3.3-diff');
    await t.scrollUntilVisible(
      find.byKey(const Key('plan-fixes')),
      -200,
      scrollable: list,
    );
    await shot(t, '3.4-fixed');

    // 3.5: «Применить» — план записан, мир перечитан: утопленник в штольне.
    await tapShown(t, find.byKey(const Key('plan-apply')));
    await t.scrollUntilVisible(
      find.text('Утопленник'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, '3.5-applied-world');

    // 3.2: повтор — операция над «Рынком» вне области, приложение её не пускает.
    await tapShown(t, find.byKey(const Key('assistant-open')));
    await pick(t, 'scope-object-location', 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('assistant-request')),
      'И рынок подтопи',
    );
    await tapShown(t, find.byKey(const Key('assistant-propose')));
    await t.scrollUntilVisible(
      find.textContaining('Вне области'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, '3.2-out-of-scope');

    // 3.6: «Отклонить» — назад в мир, в нём ничего не поменялось.
    await t.scrollUntilVisible(
      find.byKey(const Key('plan-reject')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, '3.6-before-reject');
    await tapShown(t, find.byKey(const Key('plan-reject')));
    await shot(t, '3.6-rejected-world');
    expect(content.changeSets.map((c) => c.status), ['applied', 'rejected']);
  });
}
