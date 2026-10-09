// Сообщение об успехе: после каждого завершённого действия автор видит короткое «сделано»
// с названием того, что создано, сохранено или удалено. При отказе и ошибке его нет.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'autofix_test.dart' show floodWithAttack;
import 'event_flow_test.dart' show choose;
import 'fakes.dart';
import 'history_flow_test.dart' show flood, flooded, openHistory;
import 'manual_edit_flow_test.dart' show open, openMines;
import 'open5e_test.dart' show FakeOpen5e, openLibrary, warPick;

final _done = find.byKey(const Key('done-message'));

/// На экране «сделано» с этим текстом.
void expectDone(String text) => expect(
  find.descendant(of: _done, matching: find.text(text)),
  findsOneWidget,
  reason: 'нет сообщения «$text»',
);

/// Ждём, пока «сделано» исчезнет само: полоса закрывает низ списка.
Future<void> gone(WidgetTester t) async {
  // Срок задан числом, а не константой из кода: иначе тест не заметит, что его растянули.
  await t.pump(const Duration(seconds: 3));
  await t.pumpAndSettle();
  expect(_done, findsNothing, reason: '«сделано» не исчезло само');
}

/// Мир копей открыт, сообщение о создании мира уже исчезло.
Future<FakeContent> quietMines(WidgetTester t) async {
  final content = await openMines(t);
  await gone(t);
  return content;
}

void main() {
  testWidgets('новый мир: «Мир создан» с названием; сообщение исчезает само', (
    t,
  ) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    expect(_done, findsNothing);
    await createWorld(t, 'Пепельные копи');
    expectDone('Мир создан: Пепельные копи');
    // Полоса не перехватывает нажатия: под ней можно нажимать сразу.
    final hit = t.hitTestOnBinding(t.getCenter(_done));
    expect(
      [for (final e in hit.path) e.target],
      isNot(contains(t.renderObject(_done))),
      reason: 'полоса «сделано» забирает нажатие на себя',
    );
    await gone(t);
  });

  testWidgets('правка: «Сохранено» — у места, предмета, персонажа и квеста', (
    t,
  ) async {
    await quietMines(t);
    for (final (slug, kind, title) in [
      ('shtolnya_3', 'location', 'Штольня №3'),
      ('kirka', 'item', 'Кирка'),
      ('brigadir', 'character', 'Бригадир'),
      ('obval', 'quest', 'Обвал'),
    ]) {
      await open(t, slug);
      await tapButton(t, '$kind-save');
      expectDone('Сохранено: $title');
      await gone(t);
    }
  });

  testWidgets('создание: «Создано» — у места, предмета, персонажа и квеста', (
    t,
  ) async {
    await quietMines(t);
    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'Причал');
    await tapButton(t, 'location-save');
    expectDone('Создано: Причал');
    await gone(t);

    await tapButton(t, 'new-item');
    await t.enterText(find.byKey(const Key('item-title')), 'Лом');
    await t.enterText(find.byKey(const Key('item-stat')), '2');
    await tapButton(t, 'item-save');
    expectDone('Создано: Лом');
    await gone(t);

    await tapButton(t, 'new-character');
    await t.enterText(find.byKey(const Key('character-title')), 'Сторож');
    await tapButton(t, 'character-save');
    expectDone('Создано: Сторож');
    await gone(t);

    // Список мира ленивый: раздел квестов ниже края экрана.
    await t.scrollUntilVisible(
      find.byKey(const Key('new-quest')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapButton(t, 'new-quest');
    await t.enterText(find.byKey(const Key('quest-title')), 'Смена');
    await choose(t, 'quest-giver', 'Бригадир');
    await choose(t, 'step-target-0-talk', 'Бригадир');
    await tapButton(t, 'quest-save');
    expectDone('Создано: Смена');
  });

  testWidgets('удаление: «Удалено» — после «да»; при отказе сообщения нет', (
    t,
  ) async {
    await quietMines(t);
    await open(t, 'rynok');
    await tapButton(t, 'object-delete');
    await tapButton(t, 'confirm-no');
    expect(_done, findsNothing);
    await tapButton(t, 'object-delete');
    await tapButton(t, 'confirm-yes');
    expectDone('Удалено: Рынок');
  });

  testWidgets('удаление: «Удалено» — у квеста, предмета и персонажа', (
    t,
  ) async {
    await quietMines(t);
    // Сначала квест: после него на кирку и бригадира никто не ссылается.
    for (final (slug, title) in [
      ('obval', 'Обвал'),
      ('kirka', 'Кирка'),
      ('brigadir', 'Бригадир'),
    ]) {
      await open(t, slug);
      await tapButton(t, 'object-delete');
      await tapButton(t, 'confirm-yes');
      expectDone('Удалено: $title');
      await gone(t);
    }
  });

  testWidgets(
    'удалить нельзя и поле не заполнено — «сделано» не показывается',
    (t) async {
      await quietMines(t);
      await open(t, 'klyuch');
      await tapButton(t, 'object-delete');
      expect(find.textContaining('Нельзя удалить «Ключ»'), findsOneWidget);
      expect(_done, findsNothing);
      await t.enterText(find.byKey(const Key('item-title')), '');
      await tapButton(t, 'item-save');
      expect(find.text('Нужно название предмета'), findsOneWidget);
      expect(_done, findsNothing);
    },
  );

  testWidgets('событие: создано, сохранено, удалено', (t) async {
    await quietMines(t);
    await tapButton(t, 'new-event');
    await t.enterText(find.byKey(const Key('event-title')), 'Ярмарка');
    await choose(t, 'event-location', 'Рынок');
    await tapButton(t, 'event-save');
    expectDone('Создано: Ярмарка');
    await gone(t);

    await open(t, 'yarmarka');
    await tapButton(t, 'event-save');
    expectDone('Сохранено: Ярмарка');
    await gone(t);

    await open(t, 'yarmarka');
    await tapButton(t, 'object-delete');
    await tapButton(t, 'confirm-yes');
    expectDone('Удалено: Ярмарка');
  });

  testWidgets('план: «План применён» и «План отклонён»', (t) async {
    await openAssistant(
      t,
      FakeAssistant([
        proposal(floodWithAttack(8)),
        proposal(floodWithAttack(8)),
      ]),
    );
    await ask(t);
    await tapButton(t, 'plan-reject');
    expectDone('План отклонён');
    await gone(t);

    await tapButton(t, 'assistant-open');
    await ask(t);
    await tapButton(t, 'plan-apply');
    expectDone('План применён');
  });

  testWidgets('откат: «Набор откачен» — после «да»; при отказе сообщения нет', (
    t,
  ) async {
    await flooded(t);
    await openHistory(t);
    await gone(t);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    await tapButton(t, 'revert-set-0');
    await tapButton(t, 'confirm-no');
    expect(_done, findsNothing);
    await tapButton(t, 'revert-set-0');
    await tapButton(t, 'confirm-yes');
    expectDone('Набор откачен');
  });

  testWidgets('образец Open5e: «Импортировано» с названием образца', (t) async {
    await openLibrary(t, FakeOpen5e([warPick()]));
    await tapButton(t, 'open5e-srd-2024_war-pick');
    await tapButton(t, 'open5e-import');
    expectDone('Импортировано: ${warPick().name}');
  });
}
