// Экран «История изменений» (3.7) на подменённой базе: наборы, откат, конфликт.
// Откат по-настоящему (строки, каскады, конфликт по объекту) — test/revert_db_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'autofix_test.dart' show floodWithAttack;
import 'fakes.dart';

const flood = 'Штольня №3 затоплена: слизни ушли, появились утопленники';

/// Затопление применено через ассистента, мы снова в мире.
Future<FakeContent> flooded(WidgetTester t) async {
  final (content, _) = await openAssistant(
    t,
    FakeAssistant([proposal(floodWithAttack(8))]),
  );
  await ask(t);
  await tapButton(t, 'plan-apply');
  // Список мира ленивый: персонажи теперь ниже раздела «События» — докручиваем до строки.
  await t.scrollUntilVisible(
    find.text('Утопленник'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  expect(find.text('Утопленник'), findsOneWidget);
  return content;
}

Future<void> openHistory(WidgetTester t) async {
  await t.tap(find.byKey(const Key('history-open')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('откат: затопление в истории — откатить — мир как был', (
    t,
  ) async {
    final content = await flooded(t);
    await openHistory(t);
    expect(find.text(flood), findsOneWidget);
    expect(find.textContaining('Применён'), findsOneWidget);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    expect(find.textContaining('Изменить · Локация'), findsOneWidget);

    await tapButton(t, 'revert-set-0');
    expect(
      find.byKey(const Key('revert-error-set-0'), skipOffstage: false),
      findsNothing,
    );
    expect(find.text('Откат: $flood'), findsOneWidget);
    expect(find.textContaining('Откачен'), findsOneWidget);
    expect(find.byKey(const Key('revert-set-0')), findsNothing);

    // Назад в мир — он перечитан: утопленника нет.
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Утопленник'), findsNothing);
    expect(
      (await content.characters(minesId)).map((c) => c.slug),
      isNot(contains('utoplennik')),
    );
  });

  testWidgets('откат: мир меняли после набора — конфликт, откат не идёт', (
    t,
  ) async {
    final content = await flooded(t);
    content.version++; // автор поправил мир после набора
    await openHistory(t);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    await tapButton(t, 'revert-set-0');
    expect(find.byKey(const Key('revert-conflicts-set-0')), findsOneWidget);
    expect(find.text('мир — изменён после набора'), findsOneWidget);
    expect(find.textContaining('Откачен'), findsNothing);
    expect(
      (await content.characters(minesId)).map((c) => c.slug),
      contains('utoplennik'),
    );
  });

  testWidgets('откат: отклонённый набор откатить нельзя — кнопки нет', (
    t,
  ) async {
    await openAssistant(t, FakeAssistant([proposal(floodWithAttack(8))]));
    await ask(t);
    await tapButton(t, 'plan-reject');
    await openHistory(t);
    expect(find.textContaining('Отклонён'), findsOneWidget);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('revert-set-0')), findsNothing);
  });

  testWidgets('откат: изменений не было — история пустая', (t) async {
    await openAssistant(t);
    await t.pageBack();
    await t.pumpAndSettle();
    await openHistory(t);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
  });
}
