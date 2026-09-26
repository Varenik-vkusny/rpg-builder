// ПОКАЗ, а не проверка: образец из Open5e (4.6) на подменённой базе и записанном ответе Open5e.
// Запуск: flutter test --no-pub demo/open5e_snapshots_test.dart → build/snapshots/4.6-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import '../test/open5e_test.dart' show FakeOpen5e, potion, warPick;
import 'shots.dart';

void main() {
  testWidgets('образец из Open5e: поиск, план с источником, предмет в мире', (
    t,
  ) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await pumpApp(
      t,
      content: await minesContent(),
      open5e: FakeOpen5e([warPick(), potion]),
      wrap: frame,
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await tapShown(t, find.byKey(const Key('open5e-open')));
    await t.enterText(find.byKey(const Key('open5e-query')), 'pick');
    await tapShown(t, find.byKey(const Key('open5e-search')));
    await shot(t, '4.6-open5e-search');

    await tapShown(t, find.byKey(const Key('open5e-srd-2024_war-pick')));
    await shot(t, '4.6-open5e-plan');

    await tapShown(t, find.byKey(const Key('open5e-import')));
    await t.scrollUntilVisible(
      find.text('War Pick'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, '4.6-open5e-imported');
  });
}
