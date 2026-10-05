// Кнопки «Применить» и «Отклонить» на экране ассистента (3.5–3.6), подменённая база.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/change_set.dart';

import 'assistant_fixtures.dart';
import 'autofix_test.dart' show broken, floodWithAttack;
import 'fakes.dart';

Future<void> tapButton(WidgetTester t, String key) async {
  await t.ensureVisible(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

bool enabled(WidgetTester t, String key) =>
    t.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  testWidgets('применить: план записан, мир перечитан, набор в журнале', (
    t,
  ) async {
    final (content, _) = await openAssistant(
      t,
      FakeAssistant([
        proposal(floodWithAttack(14)),
        proposal(floodWithAttack(8)),
      ]),
    );
    await ask(t);
    expect(enabled(t, 'plan-apply'), isTrue);
    await tapButton(t, 'plan-apply');

    // Снова в мире — и утопленник уже в списке.
    expect(find.byKey(const Key('assistant-open')), findsOneWidget);
    // Список мира ленивый: персонажи теперь ниже раздела «События» — докручиваем до строки.
    await t.scrollUntilVisible(
      find.text('Утопленник'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Утопленник'), findsOneWidget);
    final set = content.changeSets.single;
    expect(set.status, 'applied');
    expect((set.draft.attempts, set.draft.inputTokens), (2, 2000));
    expect(set.draft.scope!.slug, 'shtolnya_3');
    final chars = await content.characters(minesId);
    expect(chars.firstWhere((c) => c.slug == 'utoplennik').attack, 8);
  });

  testWidgets('применить: ошибки после исправлений — кнопка недоступна', (
    t,
  ) async {
    final (content, _) = await openAssistant(
      t,
      FakeAssistant(List.generate(3, (_) => proposal(broken))),
    );
    await ask(t);
    expect(enabled(t, 'plan-apply'), isFalse);
    expect(enabled(t, 'plan-reject'), isTrue);
    expect(content.changeSets, isEmpty);
  });

  testWidgets(
    'применить: база отказала — автор видит, что ничего не изменилось',
    (t) async {
      final (content, _) = await openAssistant(
        t,
        FakeAssistant([proposal(floodWithAttack(8))]),
        _RefusingContent(),
      );
      await ask(t);
      await tapButton(t, 'plan-apply');
      expect(
        find.textContaining(
          'Не удалось применить — в мире ничего не изменилось',
        ),
        findsOneWidget,
      );
      // Остались на экране плана, можно отклонить.
      expect(find.byKey(const Key('plan-reject')), findsOneWidget);
      expect(content.changeSets, isEmpty);
    },
  );

  testWidgets('отклонить: мир не изменился, набор записан как rejected', (
    t,
  ) async {
    final (content, _) = await openAssistant(
      t,
      FakeAssistant([proposal(floodWithAttack(8))]),
    );
    final before = await content.snapshotOf(minesId);
    await ask(t);
    await tapButton(t, 'plan-reject');

    expect(find.byKey(const Key('assistant-open')), findsOneWidget);
    expect(find.text('Утопленник'), findsNothing);
    expect(content.changeSets.single.status, 'rejected');
    final after = await content.snapshotOf(minesId);
    expect(after.titles, before.titles);
    expect(
      after.characters.map((c) => c.loot.length),
      before.characters.map((c) => c.loot.length),
    );
  });
}

/// База, которая отказывает в применении (например, пропала связь).
class _RefusingContent extends FakeContent {
  @override
  Future<void> applyChangeSet(String worldId, ChangeSetDraft draft) async =>
      throw StateError('нет связи с базой');
}
