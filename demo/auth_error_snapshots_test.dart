// ПОКАЗ, а не проверка (вид А): вход с ошибкой почты — красная линия и «❗ причина» у своего поля.
// Запуск: flutter test --no-pub demo/auth_error_snapshots_test.dart → build/snapshots/login-error.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('вход: ошибка почты у поля почты', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(t, wrap: frame);
    await t.enterText(find.byKey(const Key('email')), 'timur@mail');
    await t.enterText(find.byKey(const Key('password')), 'secret123');
    await t.tap(find.byKey(const Key('sign-in')));
    await t.pumpAndSettle();
    await shot(t, 'login-error', ratio: 3);
  });
}
