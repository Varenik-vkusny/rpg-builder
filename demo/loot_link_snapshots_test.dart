// ПОКАЗ, а не проверка: страница врага → нажатие на карточку добычи → страница предмета.
// В check.sh не входит.
// Запуск: flutter test --no-pub demo/loot_link_snapshots_test.dart → build/snapshots/loot-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('добыча ведёт на предмет', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await pumpApp(t, content: await minesContent(), wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await t.scrollUntilVisible(
      find.byKey(const Key('open-slizen')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tapShown(t, find.byKey(const Key('open-slizen')));
    await t.ensureVisible(find.byKey(const Key('loot-klyuch')));
    await shot(t, 'loot-1-enemy');

    await tapShown(t, find.byKey(const Key('loot-klyuch')));
    await shot(t, 'loot-2-item');
  });
}
