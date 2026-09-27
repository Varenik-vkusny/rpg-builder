// Область правки в приложении — второй замок после серверной функции.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/scope.dart';
import 'package:rpg_builder/content/content_repo.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

const shaft = Scope(ScopeType.location, 'shtolnya_3');

Plan withOp(PlanOp extra) {
  final p = floodPlan();
  return Plan(summary: p.summary, ops: [...p.ops, extra]);
}

void main() {
  test(
    'вне области: область штольни — та же, что у серверной функции',
    () async {
      final w = await (await minesContent()).snapshot(minesId);
      // Как в handler_test.ts: 1 связь — слизень; 2 связи — ключ и квест.
      expect(scopeOf(w, shaft), {
        'location:shtolnya_3',
        'character:slizen',
        'item:klyuch',
        'quest:obval',
      });
      // От квеста за 2 связи: бригадир, слизень, ключ, кирка, штольня.
      expect(scopeOf(w, const Scope(ScopeType.quest, 'obval')), {
        'quest:obval',
        'character:brigadir',
        'character:slizen',
        'item:klyuch',
        'item:kirka',
        'location:shtolnya_3',
      });
      expect(scopeOf(w, const Scope(ScopeType.quest, 'net')), isEmpty);
    },
  );

  test('вне области: план в границах и созданное планом — можно', () async {
    final w = await (await minesContent()).snapshot(minesId);
    expect(outOfScope(floodPlan(), scopeOf(w, shaft)), isEmpty);
  });

  for (final (name, op, what) in [
    (
      'изменить объект вне области',
      const PlanOp(
        action: OpAction.update,
        type: OpType.location,
        slug: 'rynok',
        fields: {'description': 'x'},
      ),
      'location:rynok',
    ),
    (
      'удалить объект вне области',
      const PlanOp(action: OpAction.delete, type: OpType.item, slug: 'kirka'),
      'item:kirka',
    ),
    (
      'сослаться на объект вне области',
      const PlanOp(
        action: OpAction.update,
        type: OpType.character,
        slug: 'slizen',
        fields: {'location': 'rynok'},
      ),
      'location:rynok',
    ),
    (
      'добыча предметом вне области',
      const PlanOp(
        action: OpAction.create,
        type: OpType.loot,
        character: 'slizen',
        item: 'kirka',
        fields: {'chance': 5},
      ),
      'item:kirka',
    ),
    (
      'цель шага без вида шага',
      const PlanOp(
        action: OpAction.update,
        type: OpType.questStep,
        quest: 'obval',
        position: 1,
        fields: {'target': 'slizen'},
      ),
      'шаг-без-вида:slizen',
    ),
    (
      'шаг квеста с целью вне области',
      const PlanOp(
        action: OpAction.update,
        type: OpType.questStep,
        quest: 'obval',
        position: 1,
        fields: {'step_kind': 'talk', 'target': 'brigadir'},
      ),
      'character:brigadir',
    ),
  ]) {
    test('вне области: $name — отклоняется', () async {
      final w = await (await minesContent()).snapshot(minesId);
      expect(outOfScope(withOp(op), scopeOf(w, shaft)), {
        5: [what],
      });
    });
  }

  testWidgets('вне области: план с чужой операцией — автор видит отказ', (
    t,
  ) async {
    final bad = withOp(
      const PlanOp(
        action: OpAction.update,
        type: OpType.location,
        slug: 'rynok',
        fields: {'description': 'x'},
      ),
    );
    await openAssistant(
      t,
      FakeAssistant(List.generate(3, (_) => proposal(bad))),
    );
    await ask(t);
    expect(
      find.text('Операций вне области: 1 — такой план применить нельзя'),
      findsOneWidget,
    );
    expect(find.text('Вне области'), findsOneWidget);
    expect(find.text('location:rynok'), findsOneWidget);
  });

  testWidgets('вне области: план в границах — отказа нет', (t) async {
    await openAssistant(t);
    await ask(t);
    expect(find.byKey(const Key('plan-out-of-scope')), findsNothing);
  });
}
