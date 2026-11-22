// Прибор С6 «Строить на полном холсте»: нить тянут от кружка-ручки на правом краю жетона;
// провёл по остальному жетону — холст листается (как в «Смотреть»); держать — поднять.
// Ручку видно только в «Строить», размер удобен пальцу (28 dp, зона 32 × 48).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'holst_build_test.dart' show build, drag, placeCenter, settle;
import 'holst_fixture.dart';
import 'holst_link_test.dart' show thread;
import 'holst_look_test.dart' show token;

const phone = Size(360, 780);

Finder handle(String slug) => find.byKey(Key('thread-$slug'));

/// Провести пальцем от [a] на [d] двенадцатью шагами.
Future<void> swipe(WidgetTester t, Offset a, Offset d) async {
  final g = await t.startGesture(a);
  for (var i = 1; i <= 12; i++) {
    await g.moveTo(a + d * (i / 12));
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await settle(t);
}

void main() {
  testWidgets('ручка: только в «Строить», кружок 28 dp на правом краю жетона', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: phone);
    expect(handle('slizen'), findsNothing);
    await build(t);
    expect(handle('slizen'), findsOneWidget);
    final tile = t.getRect(token('slizen'));
    final h = t.getRect(handle('slizen'));
    expect(h.right, closeTo(tile.right, 1));
    expect(h.width, greaterThanOrEqualTo(28));
    expect(h.height, greaterThanOrEqualTo(28));
    expect(
      h.bottom,
      closeTo(tile.bottom, 1),
      reason: 'ручка внизу правого края',
    );
    final circle = t.getSize(
      find
          .descendant(of: handle('slizen'), matching: find.byType(Container))
          .first,
    );
    expect(circle, const Size(28, 28));
  });

  testWidgets('провёл по жетону (не по ручке) — холст листается, связи нет', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: phone);
    await build(t);
    final sets = c.journal.length;
    final before = t.getTopLeft(token('slizen'));
    final body = t.getRect(token('slizen')).centerLeft + const Offset(30, 0);
    await swipe(t, body, const Offset(0, -120));
    final after = t.getTopLeft(token('slizen'));
    expect(after.dy, lessThan(before.dy - 60), reason: 'холст уехал вверх');
    expect(find.byKey(const Key('holst-wheel')), findsNothing);
    expect(find.byKey(const Key('holst-snack-title')), findsNothing);
    expect(c.journal.length, sets);
  });

  testWidgets('провёл от ручки — нить: связь встала', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: const Size(1100, 800));
    await build(t);
    final sets = c.journal.length;
    final before = t.getTopLeft(token('slizen'));
    await thread(t, 'storozh', 'obval');
    expect(find.byKey(const Key('holst-menu-talk')), findsOneWidget);
    expect(t.getTopLeft(token('slizen')), before, reason: 'холст не листался');
    await t.tap(find.byKey(const Key('holst-menu-talk')));
    await settle(t);
    expect(c.journal.length, sets + 1, reason: 'связь записана');
  });

  testWidgets('метка ⚠ не закрывает ручку: зоны касания не пересекаются', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: phone);
    await build(t);
    // Предмет из палитры: он на полке и «нельзя получить» — метка ⚠ у жетона.
    await drag(t, 'item', placeCenter(t, 'lebedka'));
    final w = await c.snapshotOf(holstWorld.id);
    final slug = w.items.firstWhere((i) => i.title == 'Предмет 1').slug;
    final shelf = find.byKey(const Key('holst-shelf'));
    final warn = find.descendant(
      of: shelf,
      matching: find.byKey(Key('warn-$slug')),
    );
    await t.dragUntilVisible(
      warn,
      find.descendant(of: shelf, matching: find.byType(ListView)),
      const Offset(-200, 0),
    );
    await settle(t);
    expect(warn, findsOneWidget);
    expect(
      t.getRect(warn).overlaps(t.getRect(handle(slug))),
      isFalse,
      reason: 'метка ⚠ поверх ручки',
    );
  });
}
