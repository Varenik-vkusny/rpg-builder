// ПОКАЗ ВИДЕО: метки вместо нитей везде (решение владельца 19.10) — план «Менять»,
// связь сразу после жеста, связь под колёсиком; плюс сдвиг холста с метками.
// Запуск: flutter test --no-pub demo/holst_tags_cases_video_test.dart
//   && bash demo/video.sh tags-plan && bash demo/video.sh tags-gesture
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/holst_change_test.dart' show everyTry, mines;
import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

Finder k(String key) => find.byKey(Key(key));
const s = Duration(milliseconds: 1000);

Future<void> pan(WidgetTester t, Video v, Offset by) async {
  const a = Offset(300, 520);
  await v.drag(a, a + by, frames: 24);
  v.hide();
  await v.wait(s);
  await v.drag(a + by, a, frames: 24);
  v.hide();
  await v.wait(s);
}

void main() {
  testWidgets('видео: метки плана «Менять»', (t) async {
    await t.runAsync(loadFont);
    final v = Video(t, 'tags-plan');
    await pumpHolst(
      t,
      await mines(),
      around: v.wrap,
      assistant: everyTry(floodPlan()),
    );
    await v.wait(s * .6);
    await v.tap(k('holst-mode-change'));
    final head = t.getRect(k('hplace-shtolnya_3'));
    await v.tapAt(head.topLeft + const Offset(40, 16));
    await t.enterText(k('holst-phrase'), 'затопи её, слизни там жить не могут');
    await v.wait(s * .4);
    await v.tap(k('holst-ask'));
    v.hide();
    await v.wait(s * 5);
    await pan(t, v, const Offset(-120, -160));
    await v.wait(s);
  });

  testWidgets('видео: метка после жеста и под колёсиком', (t) async {
    await t.runAsync(loadFont);
    final v = Video(t, 'tags-gesture');
    await pumpHolst(t, await ashMines(), around: v.wrap);
    await v.wait(s * .6);
    await v.tap(k('holst-mode-build'));
    final shelf = t.getCenter(
      find.descendant(of: k('holst-shelf'), matching: find.byType(ListView)),
    );
    await v.drag(shelf, shelf - const Offset(160, 0), frames: 18);
    await v.drag(t.getCenter(k('token-slizen')), t.getCenter(k('token-kirka')));
    v.hide();
    await v.wait(s * 1.5);
    final drum = t.getCenter(k('holst-wheel-drum'));
    await v.drag(drum, drum - const Offset(0, 96), frames: 16);
    await v.wait(s * .8);
    await v.tap(k('holst-wheel-done'));
    v.hide();
    await v.wait(s * 1.5);
    await pan(t, v, const Offset(-100, -140));
    // Ещё одна связь: квест → житель через меню.
    await v.drag(
      t.getCenter(k('token-storozh')),
      t.getCenter(k('token-obval')),
    );
    await v.wait(s * .6);
    await v.tap(k('holst-menu-talk'));
    v.hide();
    await v.wait(s * 2);
  });
}
