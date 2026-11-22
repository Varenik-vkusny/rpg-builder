// ПОКАЗ ВИДЕО (С6, 22.11): «Строить» на полном холсте — палец по жетону листает холст,
// связь тянется от кружка на правом краю жетона.
// Запуск: flutter test --no-pub demo/holst_handle_video_test.dart && bash demo/video.sh holst-handle
// Снимок: flutter test --no-pub demo/holst_handle_video_test.dart --plain-name снимок
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  const s = Duration(milliseconds: 1000);

  testWidgets('снимок: кружки в «Строить»', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    await pumpHolst(t, c, size: const Size(360, 780), wrap: frame);
    await t.tap(k('holst-mode-build'));
    await shot(t, 'handle-1-circles', ratio: 3);
  });

  testWidgets('видео: листаю по жетонам, связь — от кружка', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    final v = Video(t, 'holst-handle');
    await pumpHolst(t, c, size: const Size(360, 780), around: v.wrap);
    await v.tap(k('holst-mode-build'));
    await v.wait(s * .5);
    // Палец на самом жетоне — холст листается, нить не тянется.
    final body = t.getRect(k('token-slizen')).centerLeft + const Offset(30, 0);
    await v.drag(body, body + const Offset(0, -260), frames: 40);
    await v.wait(s * .5);
    final up = t.getRect(k('token-brigadir')).centerLeft + const Offset(30, 0);
    await v.drag(up, up + const Offset(0, 260), frames: 40);
    await v.wait(s * .5);
    // От кружка — нить: Бригадир → Обвал (на полке).
    await v.drag(
      t.getCenter(k('thread-brigadir')),
      t.getCenter(k('token-obval')),
      frames: 40,
    );
    v.hide();
    await v.wait(s * 2);
  });
}
