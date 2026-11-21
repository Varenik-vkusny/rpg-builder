// ПОКАЗ ВИДЕО (владелец 20.11): план ассистента не применить — причина словами автора,
// «Гоблину-разведчику не задана роль». Живой ассистент такой план не даёт по заказу,
// поэтому ассистент подменён: он отвечает планом с персонажем без роли.
// Запуск: flutter test --no-pub demo/plan_why_video_test.dart && bash demo/video.sh plan-why
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';

import '../test/holst_change_test.dart' show everyTry, mines;
import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  const s = Duration(milliseconds: 1000);

  testWidgets('видео: «Не получится» словами автора', (t) async {
    await t.runAsync(loadFont);
    final c = await mines();
    final plan = Plan.fromJson({
      'summary': 'гоблин',
      'ops': [
        {
          'action': 'create',
          'type': 'character',
          'slug': 'goblin_scout',
          'fields': {
            'title': 'Гоблин-разведчик',
            'role': null,
            'location': 'shtolnya_3',
          },
        },
      ],
    });
    final v = Video(t, 'plan-why');
    await pumpHolst(
      t,
      c,
      around: v.wrap,
      assistant: everyTry(plan),
      size: const Size(360, 780),
    );
    await v.wait(s * .8);
    await v.tap(k('holst-mode-change'));
    final head = t.getRect(k('hplace-shtolnya_3'));
    await v.tapAt(head.topLeft + const Offset(40, 16));
    await v.tap(k('holst-phrase'));
    const text = 'добавь гоблина-разведчика';
    for (var i = 1; i <= text.length; i += 2) {
      await t.enterText(k('holst-phrase'), text.substring(0, i));
      await v.wait(const Duration(milliseconds: 66));
    }
    await t.enterText(k('holst-phrase'), text);
    await v.wait(s * .5);
    await v.tap(k('holst-ask'));
    v.hide();
    await v.wait(s * 6);
  });
}
