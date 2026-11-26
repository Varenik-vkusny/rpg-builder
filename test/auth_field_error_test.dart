// Прибор «ошибка у своего поля» (вид А, 25.11): ошибка почты стоит под полем почты,
// выше поля пароля; поле подсвечено красной линией; у пароля — своя ошибка под ним.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'fakes_screens.dart';

void main() {
  testWidgets(
    'почта неверна: ошибка под почтой, выше поля пароля, у пароля пусто',
    (t) async {
      await pumpApp(t);
      await signUp(t, 'timur.mail.kz');
      final err = find.byKey(const Key('email-error'));
      expect(err, findsOneWidget);
      expect(
        find.descendant(
          of: err,
          matching: find.text('Нужен вид name@example.com'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: err, matching: find.byIcon(Symbols.error_rounded)),
        findsOneWidget,
      );
      final mailField = t.getRect(find.byKey(const Key('email')));
      final passField = t.getRect(find.byKey(const Key('password')));
      expect(t.getRect(err).top, greaterThanOrEqualTo(mailField.bottom - 1));
      expect(t.getRect(err).bottom, lessThanOrEqualTo(passField.top));
      expect(find.byKey(const Key('password-error')), findsNothing);
      // Прототип: ошибка почты — одной строкой (телефон 26.11: была в две).
      expect(
        t.getRect(find.text('Нужен вид name@example.com')).height,
        lessThan(30),
      );
    },
  );

  testWidgets('короткий пароль: ошибка под паролем, у почты — нет', (t) async {
    await pumpApp(t);
    await t.enterText(find.byKey(const Key('email')), 'timur@mail.kz');
    await t.enterText(find.byKey(const Key('password')), '123');
    await t.tap(find.byKey(const Key('sign-up')));
    await t.pumpAndSettle();
    final err = find.byKey(const Key('password-error'));
    expect(err, findsOneWidget);
    expect(find.byKey(const Key('email-error')), findsNothing);
    expect(
      t.getRect(err).top,
      greaterThanOrEqualTo(
        t.getRect(find.byKey(const Key('password'))).bottom - 1,
      ),
    );
  });

  testWidgets('красная линия у поля с ошибкой', (t) async {
    await pumpApp(t);
    await signUp(t, 'timur.mail.kz');
    final f = t.widget<TextField>(find.byKey(const Key('email')));
    final border = f.decoration!.enabledBorder! as UnderlineInputBorder;
    expect(
      border.borderSide.color,
      Theme.of(t.element(find.byKey(const Key('email')))).colorScheme.error,
    );
    final other = t.widget<TextField>(find.byKey(const Key('password')));
    expect(other.decoration!.enabledBorder, isNull);
  });
}
