// Путь автора внутри мира без сети: создаёт объекты и видит их в мире.
// Изоляцию содержимого между авторами в настоящей базе проверяет content_rls_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> openWorld(WidgetTester t, String title) async {
  await t.tap(find.text(title));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('автор создаёт локацию и видит её в мире', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    expect(find.text('Локаций пока нет'), findsOneWidget);

    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('location-title')), 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('location-description')),
      'Сырая и тёмная',
    );
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();

    expect(find.text('Штольня №3'), findsOneWidget);
    expect(find.text('Уровни 1–10'), findsOneWidget);
    expect(find.text('Локаций пока нет'), findsNothing);
  });

  testWidgets('локация без названия не создаётся', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();

    expect(find.text('Нужно название локации'), findsOneWidget);
  });
}
