// Автоисправление (3.4): новые проблемы копии уходят ассистенту, он правит план сам,
// не больше двух раз; ошибки после этого — «Применить» недоступно.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_flow.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/item.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

/// План затопления, где у утопленника атака [attack].
Plan floodWithAttack(int attack) {
  final p = floodPlan();
  final drowned = p.ops[1];
  return Plan(
    summary: p.summary,
    ops: [
      for (final op in p.ops)
        if (op == drowned)
          PlanOp(
            action: op.action,
            type: op.type,
            slug: op.slug,
            fields: {...op.fields, 'attack': attack},
          )
        else
          op,
    ],
  );
}

/// План с невыполнимой операцией — ошибка на копии.
const broken = Plan(
  summary: 'Сломанный',
  ops: [
    PlanOp(
      action: OpAction.update,
      type: OpType.location,
      slug: 'net_takoy',
      fields: {'title': 'x'},
    ),
  ],
);

Future<(PlanRun, FakeAssistant)> run(List<Plan> answers) async {
  final assistant = FakeAssistant([for (final p in answers) proposal(p)]);
  final world = await (await minesContent()).snapshot(minesId);
  final result = await runAssistant(
    assistant: assistant,
    world: world,
    request: const ProposeRequest(
      worldId: minesId,
      scope: Scope(ScopeType.location, 'shtolnya_3'),
      request: 'затопи её',
    ),
  );
  return (result, assistant);
}

void main() {
  test('исправление: атака 14 поймана, ассистент снизил до 8 сам', () async {
    final (r, a) = await run([floodWithAttack(14), floodWithAttack(8)]);
    expect(a.requests.length, 2);
    final fix = a.requests[1];
    expect(fix.attempt, 1);
    expect(fix.previous!.ops[1].integer('attack'), 14);
    expect(fix.problems, ['«Утопленник»: атака 14 выше потолка 10 (ур. 3)']);
    expect(r.proposal.plan.ops[1].integer('attack'), 8);
    expect(r.preview.fresh, isEmpty);
    expect((r.attempts, r.fixes, r.canApply), (2, 1, true));
    // Токены сложены за обе попытки.
    expect((r.inputTokens, r.outputTokens), (2000, 400));
  });

  test('исправление: чистый план — модель спрошена один раз', () async {
    final (r, a) = await run([floodWithAttack(8)]);
    expect(a.requests.length, 1);
    expect((r.attempts, r.canApply), (1, true));
  });

  test(
    'исправление: не больше двух — ошибки остались, применить нельзя',
    () async {
      final (r, a) = await run([broken, broken, broken, broken]);
      expect(a.requests.length, 3, reason: '1 план + 2 исправления');
      expect(a.requests.map((q) => q.attempt), [0, 1, 2]);
      expect(r.fixes, maxFixes);
      expect(r.canApply, isFalse);
    },
  );

  test(
    'исправление: осталось только предупреждение — применить можно',
    () async {
      final (r, a) = await run([
        floodWithAttack(14),
        floodWithAttack(14),
        floodWithAttack(14),
      ]);
      expect(a.requests.length, 3);
      expect(r.preview.fresh.single.message, contains('атака 14'));
      expect(r.canApply, isTrue);
    },
  );

  test('исправление: старые проблемы мира ассистенту не уходят', () async {
    // «Яблоко» нельзя получить ещё до плана — это не план принёс.
    final c = await minesContent();
    await c.createItem(
      minesId,
      const NewItem(
        title: 'Яблоко',
        kind: ItemKind.consumable,
        rarity: Rarity.common,
        level: 1,
        price: 1,
      ),
    );
    final world = await c.snapshot(minesId);
    final a = FakeAssistant([proposal(floodWithAttack(8))]);
    await runAssistant(
      assistant: a,
      world: world,
      request: const ProposeRequest(
        worldId: minesId,
        scope: Scope(ScopeType.location, 'shtolnya_3'),
        request: 'затопи её',
      ),
    );
    expect(a.requests.length, 1);
    expect(checkWorld(world), isNotEmpty);
  });

  testWidgets('исправление: экран — ассистент сам снизил атаку до 8', (
    t,
  ) async {
    await openAssistant(
      t,
      FakeAssistant([
        proposal(floodWithAttack(14)),
        proposal(floodWithAttack(8)),
      ]),
    );
    await ask(t);
    expect(find.text('Ассистент исправил сам: 1 из 2'), findsOneWidget);
    await t.tap(find.byKey(const Key('plan-fixes')));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Поймано перед исправлением 1: '
        '«Утопленник»: атака 14 выше потолка 10 (ур. 3)',
      ),
      findsOneWidget,
    );
    expectChange('Атака', null, '8');
    // Плашка проверки появляется только при проблемах.
    expect(find.byKey(const Key('plan-verdict')), findsNothing);
    expect(find.byKey(const Key('plan-blocked')), findsNothing);
  });

  testWidgets('исправление: экран — ошибки после двух исправлений', (t) async {
    final a = FakeAssistant(List.generate(4, (_) => proposal(broken)));
    await openAssistant(t, a);
    await ask(t);
    expect(a.requests.length, 3);
    expect(find.text('Ассистент исправил сам: 2 из 2'), findsOneWidget);
    expect(
      find.text(
        'Ошибки остались и после 2 исправлений — «Применить» недоступно',
      ),
      findsOneWidget,
    );
  });
}
