// Прибор «связи выбранного — метками на объектах» (выбор владельца 17.10 вместо нитей):
// белая метка со словами связи на связанном объекте; не виден — маленькая метка у края
// с его стороны; за дверью — метка на двери.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/map/gesture_link.dart';
import 'package:rpg_builder/map/holst_threads.dart' show ThreadTone;

import 'holst_fixture.dart';
import 'holst_look_test.dart' show drawnTags, tagTexts, token;

void main() {
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
      id('slizen'): 'убить ×3',
      id('zasada'): 'пройти',
      id('klyuch_ot_lebedki'): 'собрать ×1',
      id('kirka'): 'в награду',
    });
    expect(drawnTags(t).edges, isEmpty);
    // Слизень: слова со стороны Слизня, добыча — «роняет».
    await t.tap(token('slizen'));
    await t.pumpAndSettle();
    expect(tagTexts(t), {
      w.quests.single.id: 'убить ×3',
      id('klyuch_ot_lebedki'): 'роняет 35%',
      id('zasada'): 'в сцене ×3',
    });
  });

  testWidgets(
    'полка прокручена: связанный слева далеко за краем — метка у левого края',
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
    },
  );

  testWidgets(
    'связанный объект за краем полки — маленькая белая метка с той стороны',
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
      expect(edge.at.dx, greaterThan(shelf.shift(-canvas).center.dx));
      expect(edge.at.dy, greaterThanOrEqualTo(shelf.shift(-canvas).top));
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
}
