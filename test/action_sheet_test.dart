// Прибор вида А «Лист» для окон (владелец 25.11): у каждого вопроса одна структура —
// значок риска и вопрос → с чем (имя плашкой) → последствия строками → «Отмена» |
// главная (шире, справа, ≥ 52 dp). Необратимое — красная заливка и «Без отката»;
// с откатом — красная рамка; «Бросить введённое?» называет имя и изменённые поля.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'manual_edit_flow_test.dart' show open, openMines;
import 'world_manage_test.dart' show longPressWorld, startWith;

ColorScheme _scheme(WidgetTester t) =>
    Theme.of(t.element(find.byKey(const Key('confirm')))).colorScheme;

/// Главная правее и шире «Отмены», обе не ниже 52 dp.
void _mainRightAndWide(WidgetTester t) {
  final no = t.getRect(find.byKey(const Key('confirm-no')));
  final yes = t.getRect(find.byKey(const Key('confirm-yes')));
  expect(yes.left, greaterThan(no.right), reason: 'главная — справа');
  expect(yes.width, greaterThan(no.width), reason: 'главная — шире');
  expect(no.height, greaterThanOrEqualTo(52));
  expect(yes.height, greaterThanOrEqualTo(52));
}

void main() {
  testWidgets('удалить мир: красная заливка «Удалить навсегда», «Без отката»', (
    t,
  ) async {
    await startWith(t, 'Пепельные копи');
    await longPressWorld(t, 'Пепельные копи');
    // Шторка мира: имя шапкой, «Удалить» красным.
    expect(find.byKey(const Key('world-sheet')), findsOneWidget);
    final del = t.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('world-delete')),
        matching: find.text('Удалить'),
      ),
    );
    await t.tap(find.byKey(const Key('world-delete')));
    await t.pumpAndSettle();
    final s = _scheme(t);
    expect(
      del.style?.color,
      s.error,
      reason: '«Удалить» в шторке мира — красным',
    );
    _mainRightAndWide(t);
    final yes = t.widget<FilledButton>(find.byKey(const Key('confirm-yes')));
    expect(
      yes.style?.backgroundColor?.resolve({}),
      s.error,
      reason: 'необратимое — красная заливка',
    );
    final noUndo = t.widget<Text>(find.text('Нельзя откатить'));
    expect(noUndo.style?.color, s.error);
  });

  testWidgets('удалить объект: есть откат — красная рамка, не заливка', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'rynok');
    await tapButton(t, 'object-delete');
    _mainRightAndWide(t);
    final yes = t.widget<OutlinedButton>(find.byKey(const Key('confirm-yes')));
    expect(yes.style?.side?.resolve({})?.color, _scheme(t).error);
    expect(find.text('Можно откатить'), findsOneWidget);
  });

  testWidgets('бросить введённое: имя и изменённые поля', (t) async {
    await openMines(t);
    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'Причал');
    await t.pageBack();
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('sheet-subject')),
        matching: find.text('Причал'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('confirm')),
        matching: find.text('Название'),
      ),
      findsOneWidget,
      reason: 'что пропадёт',
    );
    _mainRightAndWide(t);
  });
}
