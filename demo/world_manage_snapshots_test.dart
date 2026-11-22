// ПОКАЗ, а не проверка: лист действий мира, форма переименования, вопрос удаления.
// Запуск: flutter test --no-pub demo/world_manage_snapshots_test.dart → build/snapshots/world-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('управление миром: лист, переименование, удаление', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(t, wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await createWorld(t, 'Медные холмы');
    await t.pump(const Duration(seconds: 3));
    await t.longPress(find.text('Пепельные копи'));
    await shot(t, 'world-1-sheet');
    await t.tap(find.byKey(const Key('world-rename')));
    await t.pumpAndSettle();
    await shot(t, 'world-2-rename');
    await t.pageBack();
    await t.pumpAndSettle();
    await t.longPress(find.text('Пепельные копи'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('world-delete')));
    await shot(t, 'world-3-delete');
  });
}
