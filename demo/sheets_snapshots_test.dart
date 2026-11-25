// ПОКАЗ, а не проверка: окна вида А «Лист» (25.11) — сравнить с прототипом
// Docs/rpg-builder/vid-a-snimki/wins-*.png. В check.sh не входит.
// Запуск: flutter test --no-pub demo/sheets_snapshots_test.dart → build/snapshots/sheet-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

Future<void> phone(WidgetTester t) async {
  await t.runAsync(loadFont);
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> openPage(WidgetTester t, String slug) async {
  await tapShown(t, find.byKey(Key('open-$slug')));
  await tapShown(t, find.byKey(const Key('object-edit')));
}

void main() {
  testWidgets('окна вида А', (t) async {
    await phone(t);
    await pumpApp(t, content: await minesContent(), wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');

    // Шторка мира и удаление мира.
    await t.longPress(find.text('Пепельные копи'));
    await t.pumpAndSettle();
    await shot(t, 'sheet-1-world-menu');
    await tapShown(t, find.byKey(const Key('world-delete')));
    await shot(t, 'sheet-2-world-delete');
    await tapShown(t, find.byKey(const Key('confirm-no')));

    await openWorld(t, 'Пепельные копи');

    // Удалить объект (есть откат) и отказ (на Слизня ссылается квест).
    await openPage(t, 'rynok');
    await tapShown(t, find.byKey(const Key('object-delete')));
    await shot(t, 'sheet-3-object-delete');
    await tapShown(t, find.byKey(const Key('confirm-no')));
    await t.pageBack();
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    await openPage(t, 'slizen');
    await tapShown(t, find.byKey(const Key('object-delete')));
    await shot(t, 'sheet-4-refusal');
    await tapShown(t, find.byKey(const Key('refusal-ok')));

    // Бросить введённое.
    await t.enterText(
      find.byKey(const Key('character-title')),
      'Слизень-вожак',
    );
    await t.enterText(find.byKey(const Key('character-attack')), '5');
    await t.pageBack();
    await t.pumpAndSettle();
    await shot(t, 'sheet-5-discard');
    await tapShown(t, find.byKey(const Key('confirm-yes')));
    await t.pageBack();
    await t.pumpAndSettle();

    // Откат набора: правка вручную → история → «Откатить».
    await openPage(t, 'slizen');
    await t.enterText(find.byKey(const Key('character-attack')), '6');
    await tapShown(t, find.byKey(const Key('character-save')));
    // Сохранение возвращает в списки мира — там «История».
    await tapShown(t, find.byKey(const Key('history-open')));
    await tapShown(t, find.text('Правка вручную: Слизень'));
    await tapShown(t, find.byKey(const Key('revert-set-0')));
    await shot(t, 'sheet-6-revert');
    await tapShown(t, find.byKey(const Key('confirm-no')));
  });
}
