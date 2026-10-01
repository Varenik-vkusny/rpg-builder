// ПОКАЗ, а не проверка (5а.2): Копи → вложенная Штольня №3 → житель забоя.
// В check.sh не входит.
// Запуск: flutter test --no-pub demo/place_page_snapshots_test.dart → build/snapshots/place-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/fakes.dart';
import '../test/place_page_test.dart' show nestedMines;
import 'shots.dart';

void main() {
  testWidgets('страница места: вложенные и кто здесь', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await pumpApp(t, content: await nestedMines(), wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await tapShown(t, find.byKey(const Key('open-kopi')));
    await t.ensureVisible(find.byKey(const Key('who-zaboyshchik')));
    await shot(t, 'place-1-kopi');

    await t.ensureVisible(find.byKey(const Key('inner-shtolnya_3')));
    await tapShown(t, find.byKey(const Key('inner-shtolnya_3')));
    await shot(t, 'place-2-shaft');

    await t.ensureVisible(find.byKey(const Key('inner-zaboy')));
    await tapShown(t, find.byKey(const Key('inner-zaboy')));
    await t.ensureVisible(find.byKey(const Key('who-zaboyshchik')));
    await tapShown(t, find.byKey(const Key('who-zaboyshchik')));
    await shot(t, 'place-3-resident');
  });
}
