// Прибор «назад из формы с введённым — вопрос» (телефон 22.11: всё пропадало молча).
// Пустая или нетронутая форма закрывается сразу; с изменениями — «Бросить введённое?»:
// «Отмена» оставляет в форме, «Бросить» закрывает без записи; «Сохранить» — без вопроса.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'manual_edit_flow_test.dart' show open, openMines;

final _ask = find.text('Бросить введённое?');
final _form = find.text('Новая локация');

Future<void> systemBack(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('новая форма: пустая — сразу, с введённым — вопрос', (t) async {
    final content = await openMines(t);
    await tapButton(t, 'new-location');
    await systemBack(t);
    expect(_ask, findsNothing);
    expect(_form, findsNothing);

    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'Причал');
    await t.pageBack();
    await t.pumpAndSettle();
    expect(_ask, findsOneWidget, reason: 'стрелка «назад» спрашивает');
    await tapButton(t, 'confirm-no');
    expect(_form, findsOneWidget, reason: '«Отмена» — остаёмся в форме');
    await systemBack(t);
    expect(_ask, findsOneWidget, reason: 'кнопка телефона тоже спрашивает');
    await tapButton(t, 'confirm-yes');
    expect(_form, findsNothing);
    expect(
      (await content.locations(minesId)).any((l) => l.title == 'Причал'),
      isFalse,
    );

    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'Причал');
    await tapButton(t, 'location-save');
    expect(_ask, findsNothing, reason: 'сохранение закрывает без вопроса');
    expect(_form, findsNothing);
  });

  testWidgets('форма правки: нетронутая — сразу, изменённая — вопрос', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'slizen');
    await systemBack(t);
    expect(_ask, findsNothing);
    expect(find.text('Изменить персонажа'), findsNothing);
    await systemBack(t); // со страницы объекта — в мир

    await open(t, 'slizen');
    await t.enterText(find.byKey(const Key('character-title')), 'Слизняк');
    await systemBack(t);
    expect(_ask, findsOneWidget);
  });

  testWidgets('все формы объектов: введённое — вопрос при «назад»', (t) async {
    await openMines(t);
    for (final kind in ['location', 'event', 'item', 'character', 'quest']) {
      await t.scrollUntilVisible(
        find.byKey(Key('new-$kind')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapButton(t, 'new-$kind');
      await t.enterText(find.byKey(Key('$kind-title')), 'Пробный');
      await systemBack(t);
      expect(_ask, findsOneWidget, reason: kind);
      await tapButton(t, 'confirm-yes');
      expect(find.byKey(Key('$kind-title')), findsNothing, reason: kind);
    }
  });

  testWidgets('форма мира: введённое — вопрос при «назад»', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await t.tap(find.byKey(const Key('new-world')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('world-title')), 'Пробный');
    await systemBack(t);
    expect(_ask, findsOneWidget);
  });
}
