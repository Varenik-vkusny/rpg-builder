// ПОКАЗ ВИДЕО: связи выбранного — метками на объектах; за краем — маленькая метка у края.
// Запуск: flutter test --no-pub demo/holst_tags_video_test.dart && bash demo/video.sh holst-tags
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

void main() {
  testWidgets('видео: метки', (t) async {
    await t.runAsync(loadFont);
    final v = Video(t, 'holst-tags');
    await pumpHolst(t, await ashMines(), around: v.wrap);
    const s = Duration(milliseconds: 1000);
    Finder k(String key) => find.byKey(Key(key));
    await v.wait(s * .6);
    await v.tap(k('token-obval'));
    v.hide();
    await v.wait(s * 2);
    // Полку — влево: Обвал уезжает, у левого края остаётся метка.
    final shelf = t.getCenter(
      find.descendant(of: k('holst-shelf'), matching: find.byType(ListView)),
    );
    await v.drag(shelf, shelf - const Offset(220, 0), frames: 20);
    v.hide();
    await v.wait(s * 2);
    await v.drag(
      shelf - const Offset(220, 0),
      shelf + const Offset(60, 0),
      frames: 20,
    );
    await v.tap(k('token-slizen'));
    v.hide();
    await v.wait(s * 2);
    await v.tap(k('token-brigadir'));
    v.hide();
    await v.wait(s * 2);
  });
}
