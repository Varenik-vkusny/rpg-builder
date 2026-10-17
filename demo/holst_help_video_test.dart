// ПОКАЗ ВИДЕО (5е.7): первый вход — подсказка, «?» — легенда; пустой мир — три старта.
// Запуск: flutter test --no-pub demo/holst_help_video_test.dart
//   && bash demo/video.sh holst-help && bash demo/video.sh holst-empty
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/fakes.dart';
import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  const s = Duration(milliseconds: 1000);

  testWidgets('видео: подсказка и легенда', (t) async {
    await t.runAsync(loadFont);
    final v = Video(t, 'holst-help');
    await pumpHolst(t, await ashMines(), around: v.wrap, coachSeen: false);
    await v.wait(s * 2);
    await v.tap(k('holst-coach-ok'));
    await v.wait(s * .6);
    await v.tap(k('help-screen-holst'));
    v.hide();
    await v.wait(s * 2.5);
    await v.drag(const Offset(190, 600), const Offset(190, 250), frames: 24);
    v.hide();
    await v.wait(s * 2);
  });

  testWidgets('видео: пустой мир', (t) async {
    await t.runAsync(loadFont);
    final v = Video(t, 'holst-empty');
    await pumpHolst(t, FakeContent(), around: v.wrap);
    await v.wait(s * 1.5);
    await v.tap(k('holst-start-ask'));
    v.hide();
    await v.wait(s * 2.5);
  });
}
