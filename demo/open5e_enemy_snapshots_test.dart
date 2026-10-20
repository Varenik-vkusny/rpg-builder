// ПОКАЗ, а не проверка (5д): враг из Open5e — поиск, карточка «каким станет враг».
// Запуск: flutter test --no-pub demo/open5e_enemy_snapshots_test.dart
// → build/snapshots/enemy-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/apply_flow_test.dart' show tapButton;
import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import '../test/open5e_enemy_test.dart' show creature;
import '../test/open5e_test.dart' show FakeOpen5e;
import 'shots.dart';

void main() {
  testWidgets('враг из Open5e: поиск и карточка', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(
      t,
      content: await minesContent(),
      open5e: FakeOpen5e(
        const [],
        creatures: [creature('skeleton'), creature('ochre_jelly')],
      ),
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
    await t.enterText(find.byKey(const Key('open5e-query')), 'skeleton');
    await tapShown(t, find.byKey(const Key('open5e-search')));
    await shot(t, 'enemy-1-search', ratio: 3);
    await tapShown(t, find.byKey(const Key('open5e-srd_skeleton')));
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pumpAndSettle();
    await shot(t, 'enemy-2-card', ratio: 3);
  });
}
