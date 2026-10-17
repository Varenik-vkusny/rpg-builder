// Прибор 5е.3 «Строить: из палитры в место»: тащишь врага, жителя, событие, предмет или место
// на холст — объект создан через проверку и историю, полоса «Создано… / проверено · в истории»
// и «Отменить» 5 секунд. Мимо места — «Брось в место», в мире ничего не поменялось.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/gesture_path.dart';
import 'package:rpg_builder/map/holst_parts.dart';
import 'package:rpg_builder/map/holst_snack.dart';

import 'fakes.dart';
import 'holst_fixture.dart';

Finder token(String slug) => find.byKey(Key('token-$slug'));

Future<void> build(WidgetTester t) async {
  await t.tap(find.byKey(const Key('holst-mode-build')));
  await t.pumpAndSettle();
}

/// Тащит плитку палитры [kind] в точку [to].
Future<void> drag(WidgetTester t, String kind, Offset to) async {
  final from = t.getCenter(find.byKey(Key('palette-$kind')));
  final g = await t.startGesture(from);
  for (var i = 1; i <= 10; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 10)!);
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await settle(t);
}

/// Кадры на полсекунды: «до тишины» ждать нельзя — полоса со счётчиком живёт 5 секунд
/// и за это время сама уходит.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Offset placeCenter(WidgetTester t, String slug) {
  final r = t.getRect(find.byKey(Key('hplace-$slug')));
  // Ниже шапки, в пустой части места.
  return Offset(r.left + 20, r.bottom - 10);
}

String snack(WidgetTester t) =>
    t.widget<Text>(find.byKey(const Key('holst-snack-title'))).data!;

String? snackSub(WidgetTester t) {
  final f = find.byKey(const Key('holst-snack-sub'));
  return f.evaluate().isEmpty ? null : t.widget<Text>(f).data;
}

Future<int> characters(FakeContent c) async =>
    (await c.snapshotOf(holstWorld.id)).characters.length;

void main() {
  testWidgets('враг из палитры в Бараки — создан, в истории, зелёный', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c);
    await build(t);
    final sets = c.journal.length;
    await drag(t, 'enemy', placeCenter(t, 'baraki'));

    expect(snack(t), 'Создано: Новый враг в «Бараки»');
    expect(snackSub(t), 'проверено · в истории');
    expect(c.journal.length, sets + 1);
    expect(c.journal.last.entry.request, 'Холст: создано «Новый враг»');
    final w = await c.snapshotOf(holstWorld.id);
    final made = w.characters.firstWhere((x) => x.title == 'Новый враг');
    final barracks = w.locations.firstWhere((l) => l.slug == 'baraki');
    expect(made.locationId, barracks.id);
    // На холсте — внутри Бараков, с зелёной рамкой «новое».
    final tile = find.byKey(Key('token-${made.slug}'));
    expect(
      t
          .getRect(find.byKey(const Key('hplace-baraki')))
          .contains(t.getCenter(tile)),
      isTrue,
    );
    expect(
      t
          .widget<TokenTile>(
            find.descendant(of: tile, matching: find.byType(TokenTile)),
          )
          .mark,
      Mark.isNew,
    );
  });

  testWidgets('«Отменить» — набор откачен, врага нет', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c);
    await build(t);
    final before = await characters(c);
    await drag(t, 'npc', placeCenter(t, 'rynok'));
    expect(await characters(c), before + 1);
    await t.tap(find.byKey(const Key('holst-snack-action')));
    await settle(t);
    expect(await characters(c), before);
    expect(snack(t), 'Отменено');
    expect(find.textContaining('Новый житель'), findsNothing);
    expect(c.journal.last.entry.summary, startsWith('Откат:'));
  });

  testWidgets('полоса уходит сама через 5 секунд', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c);
    await build(t);
    await drag(t, 'event', placeCenter(t, 'shtolnya_3'));
    expect(find.byKey(const Key('holst-snack')), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('holst-snack')), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('holst-snack')), findsNothing);
  });

  testWidgets('событие мимо места — «Брось в место», мир не тронут', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c);
    await build(t);
    final sets = c.journal.length;
    final shaft = t.getRect(find.byKey(const Key('hplace-shtolnya_3')));
    // Между местами и правым краем — пустой холст.
    await drag(t, 'event', Offset(shaft.right + 6, shaft.bottom + 8));
    expect(snack(t), 'Брось в место');
    expect(c.journal.length, sets);
  });

  testWidgets(
    'предмет — на полку, место — на уровень; новое предупреждение — жёлтая полоса',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c);
      await build(t);
      await drag(t, 'item', placeCenter(t, 'lebedka'));
      expect(snack(t), 'Создано: Новый предмет на полке');
      // Новый предмет нельзя получить — это предупреждение, жест применён и помечен.
      final w = await c.snapshotOf(holstWorld.id);
      final item = w.items.firstWhere((i) => i.title == 'Новый предмет');
      expect(
        t.widget<HolstSnack>(find.byType(HolstSnack)).data.tone,
        GestureTone.warn,
      );
      // Предмет — на полке с жёлтой меткой; полку докручиваем (шрифт тестов шире).
      final shelf = find.byKey(const Key('holst-shelf'));
      final warn = find.descendant(
        of: shelf,
        matching: find.byKey(Key('warn-${item.slug}')),
      );
      await t.dragUntilVisible(
        warn,
        find.descendant(of: shelf, matching: find.byType(ListView)),
        const Offset(-200, 0),
      );
      expect(warn, findsOneWidget);

      await drag(t, 'place', placeCenter(t, 'lebedka'));
      expect(snack(t), 'Создано: Новое место');
      final w2 = await c.snapshotOf(holstWorld.id);
      final place = w2.locations.firstWhere((l) => l.title == 'Новое место');
      expect(place.parentId, isNull);
      expect(find.byKey(Key('hplace-${place.slug}')), findsOneWidget);
    },
  );
}
