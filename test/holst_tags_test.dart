// Прибор «связи выбранного — метками на объектах» (выбор владельца 17.10 вместо нитей):
// белая метка со словами связи на связанном объекте; не виден — маленькая метка у края
// с его стороны; за дверью — метка на двери.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/map/gesture_link.dart';
import 'package:rpg_builder/map/holst_tags.dart';
import 'package:rpg_builder/map/holst_threads.dart' show ThreadTone;

import 'holst_fixture.dart';
import 'holst_look_test.dart' show drawnTags, tagTexts, token;

void main() {
  test('метки одного ряда не налезают друг на друга и на чужой жетон', () {
    // Полка телефона 18.11 (ширина 360): Кирка «в награду», за ней Ключи — длинная
    // метка у края экрана. Раньше её сдвигало влево прямо на метку и рамку Кирки.
    TagSpec tag(String id, double left, double width, double y) => (
      id: id,
      rect: Rect.fromLTWH(left, y, width, 48),
      text: id,
      tone: ThreadTone.hot,
      icon: null,
    );
    final kirka = tag('kirka', 145, 99, 700);
    final klyuchi = tag('klyuchi', 253, 160, 700);
    // Холст: у Бригадира длинная метка, справа вплотную отмеченная Штольня.
    final brigadir = tag('brigadir', 10, 150, 140);
    final shtolnya = tag('shtolnya', 175, 150, 140);
    final natural = {
      kirka: 60.0,
      klyuchi: 206.0,
      brigadir: 170.0,
      shtolnya: 40.0,
    };
    // Стрелка «там ещё есть» в правом верхнем углу полки.
    const arrow = Offset(344, 698);
    final r = tagRects(
      [klyuchi, kirka, brigadir, shtolnya],
      360,
      (x) => natural[x]!,
      arrows: [arrow],
    );
    for (final a in r.keys) {
      expect(r[a]!.left, greaterThanOrEqualTo(4), reason: a.id);
      expect(r[a]!.right, lessThanOrEqualTo(356), reason: a.id);
      for (final b in r.keys) {
        if (a == b) continue;
        expect(r[a]!.overlaps(r[b]!), isFalse, reason: '${a.id} на ${b.id}');
        expect(
          r[a]!.overlaps(b.rect),
          isFalse,
          reason: '${a.id} на жетоне ${b.id}',
        );
      }
    }
    // Влезает — метка целиком и с левого края своего жетона.
    expect(r[kirka], const Rect.fromLTWH(145, 692, 60, 18));
    expect(r[shtolnya], const Rect.fromLTWH(175, 132, 40, 18));
    // Длинная метка кончается до соседа справа.
    expect(r[brigadir]!.right, lessThan(175));
    // Не влезает — не уходит левее своего жетона (там рамки Кирки и выбранного),
    // а укорачивается и кончается до стрелки.
    expect(r[klyuchi]!.left, 253);
    expect(r[klyuchi]!.width, lessThan(206));
    expect(r[klyuchi]!.right, lessThan(arrow.dx - 8));
  });

  testWidgets('выбран Обвал: слова на каждом связанном объекте', (t) async {
    final c = await ashMines();
    final w = await c.snapshotOf(holstWorld.id);
    String id(String slug) => [
      ...w.characters.where((x) => x.slug == slug).map((x) => x.id),
      ...w.events.where((x) => x.slug == slug).map((x) => x.id),
      ...w.items.where((x) => x.slug == slug).map((x) => x.id),
    ].single;
    await pumpHolst(t, c, size: const Size(1100, 800));
    await t.tap(token('obval'));
    await t.pumpAndSettle();
    expect(tagTexts(t), {
      id('brigadir'): 'выдаёт',
      id('slizen'): 'шаг 1: убить ×3',
      id('zasada'): 'шаг 2: пройти',
      id('klyuch_ot_lebedki'): 'шаг 3: собрать ×1',
      id('kirka'): 'в награду',
    });
    expect(drawnTags(t).edges, isEmpty);
    // Слизень: слово про того, на ком метка — Ключ «выпадает», Засада «враги».
    await t.tap(token('slizen'));
    await t.pumpAndSettle();
    expect(tagTexts(t), {
      w.quests.single.id: 'шаг 1: убить ×3',
      id('klyuch_ot_lebedki'): 'выпадает 35%',
      id('zasada'): 'враги ×3',
    });
  });

  testWidgets(
    'полка прокручена: связанный слева далеко за краем — стрелка на левом углу',
    (t) async {
      // Длинная полка: Обвал после прокрутки до конца уже не построен вовсе.
      final c = await ashMines();
      for (var i = 1; i <= 12; i++) {
        await c.createItem(
          holstWorld.id,
          NewItem(
            title: 'Камень $i',
            kind: ItemKind.misc,
            rarity: Rarity.common,
            level: 1,
            price: 0,
          ),
        );
      }
      final w = await c.snapshotOf(holstWorld.id);
      final quest = w.quests.single.id;
      final last = w.items.last;
      await c.applyManualEdit(
        holstWorld.id,
        linkByGesture(holstWorld.id, w, LinkKind.collect, quest, last.id, 1),
      );
      await pumpHolst(t, c, size: const Size(360, 760));
      final shelf = find.descendant(
        of: find.byKey(const Key('holst-shelf')),
        matching: find.byType(ListView),
      );
      await t.dragUntilVisible(token(last.slug), shelf, const Offset(-300, 0));
      await t.pumpAndSettle();
      await t.tap(token(last.slug));
      await t.pumpAndSettle();
      expect(
        token('obval'),
        findsNothing,
        reason: 'Обвал должен уйти из дерева',
      );
      final edge = drawnTags(t).edges.where((e) => e.id == quest).single;
      final canvas = t.getTopLeft(find.byKey(const Key('holst-canvas')));
      final box = t
          .getRect(find.byKey(const Key('holst-shelf')))
          .shift(-canvas);
      expect(edge.at.dx, lessThan(box.center.dx));
      // Стрелка висит на верхнем левом углу полки и смотрит вниз-влево.
      expect((edge.at.dy - box.top).abs(), lessThanOrEqualTo(4));
      expect(edge.dir.dx < 0 && edge.dir.dy > 0, isTrue, reason: '${edge.dir}');
    },
  );

  testWidgets(
    'связанный объект за краем полки — стрелка на верхнем углу полки с той стороны',
    (t) async {
      // Узкий экран и шрифт тестов: Кирка на полке за правым краем.
      await pumpHolst(t, await ashMines(), size: const Size(360, 760));
      await t.tap(token('obval'));
      await t.pumpAndSettle();
      final w = await (await ashMines()).snapshotOf(holstWorld.id);
      final pick = w.items.firstWhere((x) => x.slug == 'kirka').id;
      final edge = drawnTags(t).edges.where((e) => e.id == pick).single;
      final shelf = t.getRect(find.byKey(const Key('holst-shelf')));
      final canvas = t.getTopLeft(find.byKey(const Key('holst-canvas')));
      final box = shelf.shift(-canvas);
      expect(edge.at.dx, greaterThan(box.center.dx));
      // Висит на верхнем правом углу полки (владелец 19.10) и смотрит вниз-вправо.
      expect((edge.at.dy - box.top).abs(), lessThanOrEqualTo(4));
      expect(edge.dir.dx > 0 && edge.dir.dy > 0, isTrue, reason: '${edge.dir}');
      expect(tagTexts(t).containsKey(pick), isFalse);
    },
  );

  testWidgets('связанный объект за дверью — метка на двери', (t) async {
    final c = await ashMines();
    final w0 = await c.snapshotOf(holstWorld.id);
    final quest = w0.quests.single.id;
    final stone = w0.characters.firstWhere((x) => x.slug == 'kamneed').id;
    await c.applyManualEdit(
      holstWorld.id,
      linkByGesture(holstWorld.id, w0, LinkKind.kill, quest, stone, 1),
    );
    await pumpHolst(t, c);
    await t.tap(token('obval'));
    await t.pumpAndSettle();
    final canvas = t.getTopLeft(find.byKey(const Key('holst-canvas')));
    final door = t.getRect(find.byKey(const Key('hdoor-zaboy'))).shift(-canvas);
    expect(drawnTags(t).doors, [(rect: door, tone: ThreadTone.hot)]);
  });

  testWidgets(
    'полка длинная, нужный предмет далеко за краем — метка у правого края',
    (t) async {
      final c = await ashMines();
      for (var i = 1; i <= 12; i++) {
        await c.createItem(
          holstWorld.id,
          NewItem(
            title: 'Камень $i',
            kind: ItemKind.misc,
            rarity: Rarity.common,
            level: 1,
            price: 0,
          ),
        );
      }
      final w0 = await c.snapshotOf(holstWorld.id);
      final last = w0.items.last.id;
      await c.applyManualEdit(
        holstWorld.id,
        linkByGesture(
          holstWorld.id,
          w0,
          LinkKind.collect,
          w0.quests.single.id,
          last,
          1,
        ),
      );
      await pumpHolst(t, c, size: const Size(360, 760));
      await t.tap(token('obval'));
      await t.pumpAndSettle();
      final edge = drawnTags(t).edges.where((e) => e.id == last).single;
      final canvas = t.getTopLeft(find.byKey(const Key('holst-canvas')));
      final shelf = t
          .getRect(find.byKey(const Key('holst-shelf')))
          .shift(-canvas);
      expect(edge.at.dx, greaterThan(shelf.center.dx));
    },
  );

  testWidgets('в покое — значки, откуда связи; выбран объект — значков нет', (
    t,
  ) async {
    final c = await ashMines();
    final w = await c.snapshotOf(holstWorld.id);
    await pumpHolst(t, c, size: const Size(1100, 800));
    final canvas = t.getTopLeft(find.byKey(const Key('holst-canvas')));
    Map<Rect, List<String>> chips() => {
      for (final b in drawnTags(t).badges)
        b.rect: [for (final x in b.chips) x.text],
    };
    Rect at(String slug) => t.getRect(token(slug)).shift(-canvas);
    // Ключ: шаг 3 квеста и выпадает из Слизня 35%.
    expect(chips()[at('klyuch_ot_lebedki')], ['3', '35%']);
    // Слизень: шаг 1 квеста и ×3 в сцене Засады.
    expect(chips()[at('slizen')], ['1', '×3']);
    expect(chips()[at('kirka')], ['']);
    expect(w.quests, hasLength(1));
    await t.tap(token('obval'));
    await t.pumpAndSettle();
    expect(drawnTags(t).badges, isEmpty);
  });
}
