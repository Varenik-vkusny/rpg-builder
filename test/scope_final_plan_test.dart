// Правило 5 в приложении: фильтр области проверяет ИТОГОВЫЙ план — тот, что остался
// после автоисправлений, — и стоит перед «Применить». Первый план в границах
// ничего не гарантирует: исправление может вывести план за область.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_flow.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/content_repo.dart';

import 'assistant_fixtures.dart';
import 'autofix_test.dart' show floodWithAttack;
import 'fakes.dart';

/// Атака исправлена на 8, но заодно тронут рынок — он вне области штольни.
Plan fixedButOutside() {
  final p = floodWithAttack(8);
  return Plan(
    summary: p.summary,
    ops: [
      ...p.ops,
      const PlanOp(
        action: OpAction.update,
        type: OpType.location,
        slug: 'rynok',
        fields: {'description': 'затоплен'},
      ),
    ],
  );
}

Future<PlanRun> runWith(List<Plan> answers) async {
  final world = await (await minesContent()).snapshot(minesId);
  return runAssistant(
    assistant: FakeAssistant([for (final p in answers) proposal(p)]),
    world: world,
    request: const ProposeRequest(
      worldId: minesId,
      scope: Scope(ScopeType.location, 'shtolnya_3'),
      request: 'затопи её',
    ),
  );
}

void main() {
  test('вне области: первый план в границах, исправление вышло за область — '
      'итог отклонён', () async {
    final r = await runWith([
      floodWithAttack(14),
      fixedButOutside(),
      fixedButOutside(),
    ]);
    expect(r.attempts, 3);
    expect(r.preview.outside, {
      5: ['location:rynok'],
    });
    expect(r.canApply, isFalse);
  });

  test('вне области: первый план за областью, исправление в границах — '
      'применить можно', () async {
    final r = await runWith([fixedButOutside(), floodWithAttack(8)]);
    expect(r.attempts, 2);
    expect(r.preview.outside, isEmpty);
    expect(r.canApply, isTrue);
  });

  testWidgets('вне области: после исправлений план за областью — '
      '«Применить» недоступно, в базу не ушло ничего', (t) async {
    final (content, _) = await openAssistant(
      t,
      FakeAssistant([
        proposal(floodWithAttack(14)),
        proposal(fixedButOutside()),
        proposal(fixedButOutside()),
      ]),
    );
    await ask(t);
    expect(find.text('Вне области: location:rynok'), findsOneWidget);
    final apply = find.byKey(const Key('plan-apply'));
    await t.ensureVisible(apply);
    expect(t.widget<FilledButton>(apply).onPressed, isNull);
    await t.tap(apply, warnIfMissed: false);
    await t.pumpAndSettle();
    expect(content.changeSets, isEmpty);
  });
}
