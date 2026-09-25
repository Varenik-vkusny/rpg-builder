// Ассистент спрашивает автора, когда просьба спорит с правилами мира: окно с вариантами
// и «Свой вариант»; ответ уходит ассистенту вместе с просьбой.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

const attack14 = AuthorQuestion(
  'Вы просили атаку 14, но у врага 3 уровня потолок 10.',
  [
    (label: 'Поставить 10', description: 'баланс в норме'),
    (label: 'Оставить 14', description: 'будет предупреждение в проверке'),
  ],
);

void main() {
  testWidgets(
    'вопрос: ассистент спрашивает — автор выбирает вариант — ответ уходит с просьбой, приходит план',
    (t) async {
      // План с атакой 14 — после ответа ещё два исправления.
      final plans = List.generate(3, (_) => proposal(floodPlan()));
      final a = FakeAssistant([attack14, ...plans]);
      await openAssistant(t, a);
      await ask(t);

      expect(find.byKey(const Key('question-dialog')), findsOneWidget);
      expect(find.text(attack14.question), findsOneWidget);
      expect(find.text('Поставить 10 (советую)'), findsOneWidget);
      expect(find.text('будет предупреждение в проверке'), findsOneWidget);
      await t.tap(find.byKey(const Key('question-option-1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('question-answer')));
      await t.pumpAndSettle();

      expect(a.requests, hasLength(4));
      expect(a.requests[0].answers, isEmpty);
      expect(a.requests[1].answers.single.question, attack14.question);
      // Ответ автора уходит и с планом, и с каждым исправлением.
      for (final r in a.requests.skip(1)) {
        expect(r.answers.single.answer, 'Оставить 14');
      }
      expect(find.byKey(const Key('plan-apply')), findsOneWidget);
    },
  );

  testWidgets(
    'вопрос: «Свой вариант» — пусто нельзя ответить, вписанный текст уходит ассистенту',
    (t) async {
      final a = FakeAssistant([attack14, proposal(floodPlan())]);
      await openAssistant(t, a);
      await ask(t);

      await t.tap(find.byKey(const Key('question-option-2')));
      await t.pumpAndSettle();
      final answer = find.byKey(const Key('question-answer'));
      expect(t.widget<FilledButton>(answer).onPressed, isNull);
      await t.enterText(
        find.byKey(const Key('question-own')),
        'Уровень 5, атака 14',
      );
      await t.pump();
      await t.tap(answer);
      await t.pumpAndSettle();

      expect(a.requests[1].answers.single.answer, 'Уровень 5, атака 14');
    },
  );

  testWidgets(
    'вопрос: автор закрыл окно — плана нет, ассистента больше не спрашивали',
    (t) async {
      final a = FakeAssistant([attack14, proposal(floodPlan())]);
      await openAssistant(t, a);
      await ask(t);

      await t.tap(find.byKey(const Key('question-cancel')));
      await t.pumpAndSettle();

      expect(a.requests, hasLength(1));
      expect(find.byKey(const Key('plan-apply')), findsNothing);
      expect(
        find.text('Без ответа ассистент план не составит'),
        findsOneWidget,
      );
    },
  );
}
