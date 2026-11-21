// ПОКАЗ, а не проверка (5д): длинная выдача «дракон» по-русски — ровно 20 находок без двойников.
// Запуск: flutter test --no-pub demo/open5e_twenty_snapshots_test.dart
// → build/snapshots/twenty-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/apply_flow_test.dart' show tapButton;
import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import '../test/open5e_test.dart' show FakeOpen5e;
import '../test/open5e_twenty_test.dart' show dragons;
import 'shots.dart';

void main() {
  testWidgets('справочник: 20 находок после склейки', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      content: await minesContent(),
      open5e: FakeOpen5e(const [], creatures: dragons()),
      wrap: frame,
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await t.scrollUntilVisible(
      find.byKey(const Key('open5e-open')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapButton(t, 'open5e-open');
    await t.tap(find.text('Враги'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('open5e-query')), 'дракон');
    await tapShown(t, find.byKey(const Key('open5e-search')));
    await shot(t, 'twenty-dragons', ratio: 1);
  });
}
