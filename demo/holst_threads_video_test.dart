// ПОКАЗ ВИДЕО: нити обходят блоки, у каждой своя полоса и своя подпись.
// Запуск: flutter test --no-pub demo/holst_threads_video_test.dart && bash demo/video.sh holst-threads
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

void main() {
  testWidgets('видео: нити в обход', (t) async {
    await t.runAsync(loadFont);
    final v = Video(t, 'holst-threads');
    await pumpHolst(t, await ashMines(), around: v.wrap);
    const s = Duration(milliseconds: 1000);
    Finder k(String key) => find.byKey(Key(key));
    await v.wait(s * .6);
    await v.tap(k('token-obval'));
    v.hide();
    await v.wait(s * 2.5);
    await v.tap(k('token-slizen'));
    v.hide();
    await v.wait(s * 2);
    await v.tap(k('token-brigadir'));
    v.hide();
    await v.wait(s * 2);
  });
}
