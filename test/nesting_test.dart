// Вложенность мест (5а.1) без базы: правила проверки, план на копии, форма места.
// База те же ошибки не пускает сама — это доказывает nesting_db_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/nesting.dart';

import 'fakes.dart';

Location place(String id, {String? parent, int min = 1, int max = 10}) =>
    Location(
      id: id,
      slug: id,
      title: id,
      description: '',
      levelMin: min,
      levelMax: max,
      parentId: parent,
    );

/// Копи › Штольня › Забой — три уровня, глубже нельзя.
final mines = [
  place('kopi', min: 1, max: 6),
  place('shtolnya', parent: 'kopi', min: 2, max: 4),
  place('zaboy', parent: 'shtolnya', min: 3, max: 4),
  place('rynok'),
];

List<String> rules(List<Location> ls) => [
  for (final p in checkWorld(WorldSnapshot(locations: ls)))
    '${p.severity.name}/${p.rule}/${p.objectId}',
];

void main() {
  test('три уровня — без проблем; путь словами', () {
    expect(rules(mines), isEmpty);
    expect(pathOf(mines, mines[2]), 'kopi › shtolnya › zaboy');
    expect(depthOf(mines, mines[2]), 3);
  });

  test('четвёртый уровень — ошибка «глубже 3 уровней»', () {
    final deep = [...mines, place('dno', parent: 'zaboy', min: 3, max: 4)];
    expect(rules(deep), ['error/location_too_deep/dno']);
  });

  test('место в самом себе и замкнутый круг — ошибка', () {
    expect(rules([place('a', parent: 'a')]), ['error/location_cycle/a']);
    expect(rules([place('a', parent: 'b'), place('b', parent: 'a')]), [
      'error/location_cycle/a',
      'error/location_cycle/b',
    ]);
  });

  test('родителя нет в мире — ошибка ссылки', () {
    expect(rules([place('a', parent: 'nope')]), ['error/broken_link/a']);
  });

  test('уровни вне уровней родителя — предупреждение', () {
    final ls = [
      place('kopi', min: 1, max: 4),
      place('shtolnya', parent: 'kopi', min: 3, max: 7),
    ];
    expect(rules(ls), ['warning/location_levels_outside_parent/shtolnya']);
  });

  test('куда можно положить: не в себя, не во вложенные, не глубже 3', () {
    String ids(List<Location> ls) => ls.map((l) => l.id).join(',');
    // Новое место — в любое, кроме третьего уровня.
    expect(ids(allowedParents(mines, null)), 'kopi,shtolnya,rynok');
    // Штольня с забоем занимает 2 уровня — только в место верхнего уровня.
    expect(ids(allowedParents(mines, mines[1])), 'kopi,rynok');
    // Копи с тремя уровнями внутри никуда не положить.
    expect(ids(allowedParents(mines, mines[0])), '');
  });

  group('план на копии', () {
    final world = WorldSnapshot(locations: mines);
    OpResult run(PlanOp op) =>
        applyToCopy(world, Plan(summary: '', ops: [op])).$2.single;
    WorldSnapshot copy(List<PlanOp> ops) =>
        applyToCopy(world, Plan(summary: '', ops: ops)).$1;

    test('новое место внутри — «Внутри места» в «было → стало»', () {
      final op = PlanOp(
        action: OpAction.create,
        type: OpType.location,
        slug: 'kolodec',
        fields: const {
          'title': 'Колодец',
          'level_min': 2,
          'level_max': 3,
          'parent': 'shtolnya',
        },
      );
      expect(run(op).error, isNull);
      expect(
        run(op).changes.map((c) => '${c.label}: ${c.after}'),
        contains('Внутри места: shtolnya'),
      );
      expect(checkWorld(copy([op])), isEmpty);
    });

    test('положить на четвёртый уровень — копия ловит ошибку', () {
      final op = PlanOp(
        action: OpAction.update,
        type: OpType.location,
        slug: 'rynok',
        fields: const {'parent': 'zaboy'},
      );
      expect(
        checkWorld(copy([op])).map((p) => p.rule),
        contains('location_too_deep'),
      );
    });

    test('«» — на верхний уровень', () {
      final op = PlanOp(
        action: OpAction.update,
        type: OpType.location,
        slug: 'zaboy',
        fields: const {'parent': ''},
      );
      expect(
        copy([op]).locations.firstWhere((l) => l.id == 'zaboy').parentId,
        isNull,
      );
    });

    test('удалить место с вложенными — нельзя', () {
      final op = PlanOp(
        action: OpAction.delete,
        type: OpType.location,
        slug: 'shtolnya',
      );
      expect(run(op).error, contains('вложено сюда: «zaboy»'));
    });
  });

  testWidgets('форма: новое место кладётся внутрь выбранного', (t) async {
    final content = FakeContent();
    await pumpApp(t, content: content);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    Future<void> newPlace(String title, [String? inside]) async {
      await t.tap(find.byKey(const Key('new-location')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('location-title')), title);
      if (inside != null) {
        await t.tap(find.byKey(const Key('location-parent')));
        await t.pumpAndSettle();
        await t.tap(find.text(inside).last);
        await t.pumpAndSettle();
      }
      await t.ensureVisible(find.byKey(const Key('location-save')));
      await t.tap(find.byKey(const Key('location-save')));
      await t.pumpAndSettle();
    }

    await newPlace('Копи');
    await newPlace('Штольня №3', 'Копи');
    await newPlace('Забой', 'Копи › Штольня №3');

    final ls = await content.locations('0-Пепельные копи');
    expect(
      [for (final l in ls) pathOf(ls, l)],
      ['Копи', 'Копи › Штольня №3', 'Копи › Штольня №3 › Забой'],
    );

    // Третий уровень занят — в выборе его нет.
    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('location-parent')));
    await t.pumpAndSettle();
    expect(find.text('Копи › Штольня №3 › Забой'), findsNothing);
  });
}
