// ПОКАЗ, а не проверка: карточка предмета из Open5e перед импортом (короткая, как у врага).
// Запуск: flutter test --no-pub demo/open5e_item_snapshots_test.dart → build/snapshots/item-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/apply_flow_test.dart' show tapButton;
import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import '../test/open5e_test.dart' show FakeOpen5e, potion, warPick;
import 'shots.dart';

void main() {
  testWidgets('предмет из Open5e: карточка', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 760);
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
    await t.scrollUntilVisible(
      find.byKey(const Key('open5e-open')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapButton(t, 'open5e-open');
    await t.enterText(find.byKey(const Key('open5e-query')), 'pick');
    await tapShown(t, find.byKey(const Key('open5e-search')));
    await tapShown(t, find.byKey(const Key('open5e-srd_potion-of-healing')));
    await shot(t, 'item-card', ratio: 3);
  });
}
