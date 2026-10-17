// Прибор 5е.5 «Строить: перенос жестом»: держишь объект и тащишь в другое место —
// перенесено через проверку и историю. Предупреждение (враг сильнее места) — жёлтая метка
// и «Откатить»; ошибка (место внутрь самого себя) — блок возвращается, внизу причина.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/gesture_move.dart';
import 'package:rpg_builder/map/gesture_path.dart';

import 'fakes.dart';
import 'holst_build_test.dart' show build, settle, snack, snackSub;
import 'holst_fixture.dart';
import 'holst_look_test.dart' show token;

const wide = Size(1100, 800);

/// Держать [from] до подъёма и отпустить в точке [to].
Future<void> carry(WidgetTester t, Finder from, Offset to) =>
    carryAt(t, t.getCenter(from), to);

/// То же, но держать в точке [a] (место — за шапку).
Future<void> carryAt(WidgetTester t, Offset a, Offset to) async {
  final g = await t.startGesture(a);
  await t.pump(const Duration(milliseconds: 600));
  for (var i = 1; i <= 12; i++) {
    await g.moveTo(Offset.lerp(a, to, i / 12)!);
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await settle(t);
}

/// Пустая часть места [slug] — ниже его жетонов.
Offset inside(WidgetTester t, String slug) {
  final r = t.getRect(find.byKey(Key('hplace-$slug')));
  return Offset(r.right - 12, r.bottom - 8);
}

Future<String?> placeOf(FakeContent c, String slug) async {
  final w = await c.snapshotOf(holstWorld.id);
  final id = w.characters.firstWhere((x) => x.slug == slug).locationId;
  return w.locations.where((l) => l.id == id).firstOrNull?.slug;
}

void main() {
  testWidgets(
    'житель — в Рынок: перенесено, в истории, «Отменить» возвращает',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c, size: wide);
      await build(t);
      final sets = c.journal.length;
      await carry(t, token('storozh'), inside(t, 'rynok'));
      expect(snack(t), 'Перенесено: Сторож → Рынок');
      expect(snackSub(t), 'проверено · в истории');
      expect(await placeOf(c, 'storozh'), 'rynok');
      expect(c.journal.length, sets + 1);
      final market = t.getRect(find.byKey(const Key('hplace-rynok')));
      await t.pump(const Duration(seconds: 1));
      expect(market.contains(t.getCenter(token('storozh'))), isTrue);
      await t.tap(find.byKey(const Key('holst-snack-action')));
      await settle(t);
      expect(await placeOf(c, 'storozh'), 'lebedka');
    },
  );

  testWidgets('враг сильнее места — жёлтая метка; «Откатить» из метки', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: wide);
    await build(t);
    // Слизень ур. 4 → Рынок ур. 1–2: предупреждение, жест применён.
    await carry(t, token('slizen'), inside(t, 'rynok'));
    expect(snack(t), 'Перенесено: Слизень → Рынок');
    expect(await placeOf(c, 'slizen'), 'rynok');
    expect(find.byKey(const Key('warn-slizen')), findsOneWidget);
    await t.tap(find.byKey(const Key('warn-slizen')));
    await settle(t);
    expect(find.byKey(const Key('holst-mark-sheet')), findsOneWidget);
    await t.tap(find.byKey(const Key('holst-mark-back')));
    await settle(t);
    expect(await placeOf(c, 'slizen'), 'shtolnya_3');
    expect(find.byKey(const Key('warn-slizen')), findsNothing);
    expect(snack(t), 'Откачено: Слизень → Штольня №3');
  });

  testWidgets('место внутрь своего вложенного — не перенесено, причина внизу', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: wide);
    await build(t);
    final sets = c.journal.length;
    // Штольню держат за шапку и бросают на её же дверь «Забой».
    final head = t.getRect(find.byKey(const Key('hplace-shtolnya_3')));
    await carryAt(
      t,
      head.topLeft + const Offset(40, 16),
      t.getCenter(find.byKey(const Key('hdoor-zaboy'))),
    );
    expect(snack(t), 'Не перенесено: Штольня №3');
    expect(snackSub(t), contains('само в себе'));
    expect(c.journal.length, sets);
    await t.pump(const Duration(seconds: 1));
    expect(
      t.getRect(find.byKey(const Key('hplace-shtolnya_3'))).topLeft,
      head.topLeft,
    );
  });

  testWidgets('отпустил мимо мест — блок вернулся, мир не тронут', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: wide);
    await build(t);
    final sets = c.journal.length;
    final r = t.getRect(token('storozh'));
    await carry(t, token('storozh'), r.center + const Offset(500, 0));
    expect(snack(t), 'Брось в место');
    expect(c.journal.length, sets);
    await t.pump(const Duration(seconds: 1));
    expect(t.getRect(token('storozh')), r);
  });

  test(
    'дорога: место внутрь самого себя — ошибка проверки, не записано',
    () async {
      final c = await ashMines();
      final w = await c.snapshotOf(holstWorld.id);
      final shaft = w.locations.firstWhere((l) => l.slug == 'shtolnya_3');
      final face = w.locations.firstWhere((l) => l.slug == 'zaboy');
      final r = await applyGesture(
        c,
        holstWorld.id,
        w,
        movePlace(holstWorld.id, w, shaft.id, face.id),
      );
      expect(r.tone, GestureTone.error);
      expect(r.reason, contains('само в себе'));
    },
  );
}
