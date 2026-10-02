// ПОКАЗ, а не проверка (5а.3–5а.5): карта-холст, блоки «рамка-план» на мире с вложенностью
// и проблемой; вход в Копи и Штольню, пустой уровень. В check.sh не входит.
// Запуск: flutter test --no-pub demo/map_snapshots_test.dart → build/snapshots/map-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/location.dart';

import '../test/fakes.dart';
import '../test/map_levels_test.dart' show enter;
import '../test/map_test.dart' show openMap;
import '../test/place_page_test.dart' show nestedMines, worldId;
import 'shots.dart';

void main() {
  testWidgets('карта: блоки мест', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final c = await nestedMines();
    for (final title in ['Кузня', 'Храм пепла']) {
      await c.createLocation(
        worldId,
        NewLocation(title: title, description: '', levelMin: 3, levelMax: 6),
      );
    }
    // Враг сильнее потолка уровня на рынке — предупреждение на блоке.
    final market = (await c.locations(worldId))
        .firstWhere((l) => l.slug == 'rynok');
    await c.createCharacter(
      worldId,
      NewCharacter(
        title: 'Пепельный голем',
        description: '',
        role: Role.enemy,
        locationId: market.id,
        level: 2,
        attack: 30,
      ),
    );

    await pumpApp(t, content: c, wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await openMap(t);
    await shot(t, 'map-1-level');

    await enter(t, 'kopi');
    await shot(t, 'map-2-kopi');
    await enter(t, 'shtolnya_3');
    await shot(t, 'map-3-shaft');
    await enter(t, 'zaboy');
    await shot(t, 'map-4-empty');
  });
}
