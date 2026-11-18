// ПОКАЗ, а не проверка (правки владельца 18.11): ширина телефона 360.
// Выбран квест — метки на полке не налезают; лупа в шапке без слова; страница квеста —
// отступ под шапкой и номер шага своей колонкой.
// В check.sh не входит. Запуск: flutter test --no-pub demo/holst_polish_snapshots_test.dart
// → build/snapshots/polish-*.png (×3).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_builder/content/quest.dart';

import '../test/holst_fixture.dart';
import 'shots.dart';

void main() {
  testWidgets('холст и страница квеста на телефоне', (t) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    await pumpHolst(t, c, size: const Size(360, 780), wrap: frame);
    await t.tap(find.byKey(const Key('token-obval')));
    await shot(t, 'polish-1-quest-tags', ratio: 3);

    // Полка сдвинута: Ключ с длинной меткой и Кирка «в награду» рядом, у края экрана.
    await t.drag(find.byKey(const Key('holst-shelf')), const Offset(-120, 0));
    await shot(t, 'polish-1b-shelf-edge', ratio: 3);

    await t.tap(find.byKey(const Key('holst-page')));
    await shot(t, 'polish-2-quest-page', ratio: 3);
  });

  testWidgets('полка как у владельца 18.11: Кирка и Ключи в награду рядом', (
    t,
  ) async {
    await t.runAsync(loadFont);
    final c = await ashMines();
    final w = await c.snapshotOf(holstWorld.id);
    String id(String slug) => [
      ...w.characters.where((x) => x.slug == slug).map((x) => x.id),
      ...w.items.where((x) => x.slug == slug).map((x) => x.id),
    ].single;
    await c.createQuest(
      holstWorld.id,
      NewQuest(
        title: 'Завал',
        description: '',
        giverId: id('brigadir'),
        steps: [
          QuestStep(kind: StepKind.talk, targetId: id('brigadir')),
          QuestStep(
            kind: StepKind.collect,
            targetId: id('klyuch_ot_lebedki'),
            amount: 1,
          ),
        ],
        rewardIds: [id('kirka'), id('klyuch_ot_lebedki')],
      ),
    );
    await pumpHolst(t, c, size: const Size(360, 780), wrap: frame);
    await t.tap(find.byKey(const Key('token-zaval')));
    await shot(t, 'polish-3-owner-shelf', ratio: 3);
    await t.drag(find.byKey(const Key('holst-shelf')), const Offset(-90, 0));
    await shot(t, 'polish-3b-owner-shelf', ratio: 3);

    // Шапка внутри: мир мелко, путь крупно; назад — сразу наверх, к имени мира.
    await t.tap(find.byKey(const Key('hdoor-zaboy')));
    await shot(t, 'polish-4-inside', ratio: 3);
    await t.tap(find.byKey(const Key('holst-back')));
    await shot(t, 'polish-5-back-top', ratio: 3);
  });
}
