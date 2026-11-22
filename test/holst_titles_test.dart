// Прибор С5: объекты из палитры получают разные имена по виду — «Враг 1», «Враг 2»,
// «Житель 1»; проверка мира не ругается на «название повторяется».
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/map/gesture_create.dart';

import 'holst_build_test.dart' show build, drag, placeCenter, snack;
import 'holst_fixture.dart';

void main() {
  testWidgets('три врага и житель подряд — имена разные, повторов нет', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c);
    await build(t);
    await drag(t, 'enemy', placeCenter(t, 'baraki'));
    expect(snack(t), 'Создано: Враг 1 в Бараках');
    await drag(t, 'enemy', placeCenter(t, 'baraki'));
    expect(snack(t), startsWith('Создано: Враг 2'));
    await drag(t, 'enemy', placeCenter(t, 'baraki'));
    await drag(t, 'npc', placeCenter(t, 'rynok'));
    expect(snack(t), startsWith('Создано: Житель 1'));

    final w = await c.snapshotOf(holstWorld.id);
    final names = w.characters.map((x) => x.title).toList();
    expect(names, containsAll(['Враг 1', 'Враг 2', 'Враг 3', 'Житель 1']));
    expect(names.toSet().length, names.length, reason: 'имена не повторяются');
    expect(
      checkWorld(w).where((p) => p.message.contains('название повторяется')),
      isEmpty,
    );
  });

  test('следующий свободный номер среди объектов своего вида', () async {
    final w = await ashMines().then((c) => c.snapshotOf(holstWorld.id));
    expect(nextTitle(NewKind.enemy, w), 'Враг 1');
    expect(nextTitle(NewKind.item, w), 'Предмет 1');
    expect(nextTitle(NewKind.event, w), 'Событие 1');
    expect(nextTitle(NewKind.place, w), 'Место 1');
  });

  test(
    'номер занят автором — жителем или без регистра — берётся следующий',
    () {
      Character c(String title, Role role) => Character(
        id: title,
        slug: title,
        title: title,
        description: '',
        role: role,
        locationId: null,
        loot: const [],
      );
      // Житель «Враг 1» и враг « враг 2 » — оба занимают номера (как в проверке мира).
      final w = WorldSnapshot(
        characters: [c('Враг 1', Role.npc), c(' враг 2 ', Role.enemy)],
      );
      expect(nextTitle(NewKind.enemy, w), 'Враг 3');
    },
  );

  testWidgets('полоса: место в предложном падеже; не угадать — запасной вид', (
    t,
  ) async {
    final c = await ashMines();
    await pumpHolst(t, c);
    await build(t);
    await drag(t, 'npc', placeCenter(t, 'rynok'));
    expect(snack(t), 'Создано: Житель 1 в Рынке');
    await drag(t, 'event', placeCenter(t, 'baraki'));
    expect(snack(t), 'Создано: Событие 1 в Бараках');
    await drag(t, 'enemy', placeCenter(t, 'shtolnya_3'));
    expect(snack(t), 'Создано: Враг 1 в Штольне №3');
  });
}
