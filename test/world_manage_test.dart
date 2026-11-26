// Изменить и удалить свой мир из «Мои миры»: долгое нажатие → лист действий.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> longPressWorld(WidgetTester t, String title) async {
  await t.longPress(find.text(title));
  await t.pumpAndSettle();
}

Future<void> startWith(WidgetTester t, String title) async {
  await pumpApp(t);
  await signUp(t, 'a@test.dev');
  await createWorld(t, title);
}

void main() {
  testWidgets(
    // Владелец 25.11: кнопка «Изменить» — она открывает всю форму мира, не только имя.
    'изменить: форма с заполненными полями, в списке новое имя',
    (t) async {
      await startWith(t, 'Пепельные копи');
      await longPressWorld(t, 'Пепельные копи');
      expect(find.text('Изменить'), findsOneWidget);
      expect(find.text('Переименовать'), findsNothing);
      expect(find.text('Удалить'), findsOneWidget);
      await t.tap(find.byKey(const Key('world-edit')));
      await t.pumpAndSettle();
      expect(find.text('Пепельные копи'), findsOneWidget); // в поле
      expect(find.text('Сохранить'), findsOneWidget);
      await t.enterText(find.byKey(const Key('world-title')), 'Медные холмы');
      await t.tap(find.byKey(const Key('world-save')));
      await t.pumpAndSettle();
      expect(find.text('Медные холмы'), findsOneWidget);
      expect(find.text('Пепельные копи'), findsNothing);
    },
  );

  testWidgets('изменить: пустое и слишком длинное название не уходят', (
    t,
  ) async {
    await startWith(t, 'Пепельные копи');
    await longPressWorld(t, 'Пепельные копи');
    await t.tap(find.byKey(const Key('world-edit')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('world-title')), '   ');
    await t.tap(find.byKey(const Key('world-save')));
    await t.pumpAndSettle();
    expect(find.text('Нужно название мира'), findsOneWidget);
    await t.enterText(find.byKey(const Key('world-title')), 'я' * 121);
    await t.tap(find.byKey(const Key('world-save')));
    await t.pumpAndSettle();
    expect(find.textContaining('Слишком длинно'), findsOneWidget);
  });

  testWidgets('удалить: «Отмена» — мир на месте, «Удалить» — мира нет', (
    t,
  ) async {
    await startWith(t, 'Пепельные копи');
    await longPressWorld(t, 'Пепельные копи');
    await t.tap(find.byKey(const Key('world-delete')));
    await t.pumpAndSettle();
    // Вид А: необратимое — «Удалить мир?», имя плашкой, «Без отката» красным.
    expect(find.text('Удалить мир?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sheet-subject')),
        matching: find.text('Пепельные копи'),
      ),
      findsOneWidget,
    );
    expect(find.text('Нельзя откатить'), findsOneWidget);
    expect(find.text('Удалить навсегда'), findsOneWidget);
    await t.tap(find.byKey(const Key('confirm-no')));
    await t.pumpAndSettle();
    expect(find.text('Пепельные копи'), findsOneWidget);

    await longPressWorld(t, 'Пепельные копи');
    await t.tap(find.byKey(const Key('world-delete')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-yes')));
    await t.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Пепельные копи'), findsNothing);
    expect(find.text('Миров пока нет'), findsOneWidget);
  });
}
