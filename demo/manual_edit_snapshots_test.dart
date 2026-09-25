// ПОКАЗ, а не проверка: правка и удаление вручную (4.1) на подменённой базе.
// Запуск: flutter test --no-pub demo/manual_edit_snapshots_test.dart → build/snapshots/4.1-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('правка слизня, отказ удалить ключ, история', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await pumpApp(
      t,
      content: await minesContent(),
      assistant: FakeAssistant(),
      wrap: frame,
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await tapShown(t, find.byKey(const Key('open-slizen')));
    await shot(t, '4.1-edit-slime');
    await t.enterText(
      find.byKey(const Key('character-description')),
      'сбежал в пещеры',
    );
    await tapShown(t, find.byKey(const Key('character-save')));

    await tapShown(t, find.byKey(const Key('open-klyuch')));
    await tapShown(t, find.byKey(const Key('object-delete')));
    await shot(t, '4.1-delete-refused');
    await t.pageBack();
    await t.pumpAndSettle();

    await tapShown(t, find.byKey(const Key('history-open')));
    await tapShown(t, find.text('Правка вручную: Слизень'));
    await shot(t, '4.1-history');
  });
}
