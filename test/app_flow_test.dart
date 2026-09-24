// Путь автора по экранам без сети: регистрация → новый мир → он в списке.
// База подменена памятью; изоляцию между авторами проверяет worlds_rls_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/app.dart';

import 'fakes.dart';

void main() {
  testWidgets('автор регистрируется, создаёт мир и видит его в списке', (
    t,
  ) async {
    await pumpApp(t);

    await signUp(t, 'a@test.dev');
    expect(find.text('Мои миры'), findsOneWidget);
    expect(find.text('Миров пока нет'), findsOneWidget);

    await t.tap(find.byKey(const Key('new-world')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('world-title')), 'Пепельные копи');
    await t.enterText(
      find.byKey(const Key('world-setting')),
      'Шахтёрский посёлок',
    );
    await t.enterText(find.byKey(const Key('world-tone')), 'мрачный');
    await t.tap(find.byKey(const Key('world-save')));
    await t.pumpAndSettle();

    expect(find.text('Пепельные копи'), findsOneWidget);
    expect(find.text('Уровни 1–10 · мрачный'), findsOneWidget);

    // Второй аккаунт мир не видит.
    await t.tap(find.byKey(const Key('sign-out')));
    await t.pumpAndSettle();
    await signUp(t, 'b@test.dev');
    expect(find.text('Пепельные копи'), findsNothing);
    expect(find.text('Миров пока нет'), findsOneWidget);
  });

  testWidgets('мир без названия не создаётся', (t) async {
    final auth = FakeAuth();
    final repo = FakeWorlds(auth);
    await t.pumpWidget(
      RpgBuilderApp(auth: auth, worlds: repo, content: FakeContent()),
    );
    await signUp(t, 'a@test.dev');

    await t.tap(find.byKey(const Key('new-world')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('world-save')));
    await t.pumpAndSettle();

    expect(find.text('Нужно название мира'), findsOneWidget);
    expect(await repo.listMine(), isEmpty);
  });
}
