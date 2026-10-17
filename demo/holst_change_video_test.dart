// ПОКАЗ ВИДЕО (5е.6): «Менять» — фраза, план проступает на холсте по шагу, «Применить»,
// «Откатить»; длинный план — списком с «показать на холсте» и меткой на двери.
// Запуск: flutter test --no-pub demo/holst_change_video_test.dart
//   && bash demo/video.sh holst-change && bash demo/video.sh holst-change-big
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/holst_change_test.dart' show everyTry, mines, sevenEnemies;
import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  const s = Duration(milliseconds: 1000);

  Future<void> phrase(WidgetTester t, Video v, String text) async {
    await v.tap(k('holst-mode-change'));
    final head = t.getRect(k('hplace-shtolnya_3'));
    await v.tapAt(head.topLeft + const Offset(40, 16));
    await v.tap(k('holst-phrase'));
    // Фраза «печатается» по буквам.
    for (var i = 1; i <= text.length; i += 2) {
      await t.enterText(k('holst-phrase'), text.substring(0, i));
      await v.wait(const Duration(milliseconds: 66));
    }
    await t.enterText(k('holst-phrase'), text);
    await v.wait(s * .5);
    await v.tap(k('holst-ask'));
  }

  testWidgets('видео: план по шагу', (t) async {
    await t.runAsync(loadFont);
    final c = await mines();
    final v = Video(t, 'holst-change');
    await pumpHolst(t, c, around: v.wrap, assistant: everyTry(floodPlan()));
    await v.wait(s * .8);
    await phrase(t, v, 'затопи её, слизни там жить не могут');
    v.hide();
    await v.wait(s * 5);
    await v.tap(k('holst-plan-apply'));
    v.hide();
    await v.wait(s * 2);
    await v.tap(k('holst-snack-action'));
    v.hide();
    await v.wait(s * 2);
  });

  testWidgets('видео: длинный план списком', (t) async {
    await t.runAsync(loadFont);
    final c = await mines();
    final v = Video(t, 'holst-change-big');
    await pumpHolst(t, c, around: v.wrap, assistant: everyTry(sevenEnemies()));
    await v.wait(s * .5);
    await phrase(t, v, 'поставь семь врагов');
    v.hide();
    await v.wait(s * 1.5);
    await v.tap(find.byTooltip('Показать на холсте').at(2));
    await v.wait(s * 1.5);
    await v.tap(k('holst-plan-list'));
    await v.wait(s * 1.2);
    await v.tap(k('holst-plan-reject'));
    v.hide();
    await v.wait(s * 1.5);
  });
}
