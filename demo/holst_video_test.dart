// ПОКАЗ ВИДЕО, а не проверка (5е): прогулка по холсту — смотреть, строить из палитры,
// связь жестом, перенос с предупреждением и с ошибкой. В check.sh не входит.
// Запуск: flutter test --no-pub demo/holst_video_test.dart && bash demo/video.sh holst-tour
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';
import 'video.dart';

void main() {
  testWidgets('видео: холст 5е.2–5е.5', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    final v = Video(t, 'holst-tour');
    await pumpHolst(t, c, around: v.wrap);
    Finder k(String key) => find.byKey(Key(key));
    const s = Duration(milliseconds: 1000);

    // Смотреть: нити Слизня, нити квеста, издалека и обратно.
    await v.wait(s);
    await v.tap(k('token-slizen'));
    await v.wait(s * 1.5);
    await v.tap(k('token-obval'));
    await v.wait(s * 1.5);
    await v.tap(k('holst-zoom'));
    await v.wait(s * 1.2);
    await v.tap(k('holst-zoom'));
    await v.wait(s * .8);

    // Строить: враг из палитры в Бараки.
    await v.tap(k('holst-mode-build'));
    final barracks = t.getRect(k('hplace-baraki'));
    await v.drag(
      t.getCenter(k('palette-enemy')),
      Offset(barracks.left + 60, barracks.bottom - 20),
    );
    await v.wait(s * 2);

    // Связь: Слизень → Кирка, колёсико «Шанс» 40%.
    final shelf = find.descendant(
      of: k('holst-shelf'),
      matching: find.byType(ListView),
    );
    final sh = t.getCenter(shelf);
    await v.drag(sh, sh - const Offset(160, 0), frames: 18);
    await v.drag(t.getCenter(k('token-slizen')), t.getCenter(k('token-kirka')));
    await v.wait(s * .6);
    final drum = t.getCenter(k('holst-wheel-drum'));
    await v.drag(drum, drum - const Offset(0, 144), frames: 20);
    await v.wait(s * .8);
    await v.tap(k('holst-wheel-done'));
    await v.wait(s * 1.5);

    // Квест → житель: меню «Поговорить / Убить».
    await v.drag(t.getCenter(k('token-storozh')), t.getCenter(k('token-obval')));
    await v.wait(s * .8);
    await v.tap(k('holst-menu-talk'));
    await v.wait(s * 1.5);

    // Перенос: Слизень в Рынок — жёлтая метка, «Откатить».
    final market = t.getRect(k('hplace-rynok'));
    await v.drag(
      t.getCenter(k('token-slizen')),
      Offset(market.center.dx, market.bottom - 30),
      hold: const Duration(milliseconds: 650),
    );
    await v.wait(s * 1.5);
    await v.tap(k('warn-slizen'));
    await v.wait(s);
    await v.tap(k('holst-mark-back'));
    await v.wait(s * 1.5);

    // Ошибка: Штольню — в её же Забой. Не перенесено, блок вернулся, причина внизу.
    final head = t.getRect(k('hplace-shtolnya_3'));
    await v.drag(
      head.topLeft + const Offset(40, 16),
      t.getCenter(k('hdoor-zaboy')),
      hold: const Duration(milliseconds: 650),
    );
    v.hide();
    await v.wait(s * 2.5);
    debugPrint('кадров: ${v.frames}');
  });
}
