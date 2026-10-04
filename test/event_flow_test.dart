// Событие на экранах (5б.1), подменённая база: создать «Засаду у лебёдки» в Штольне №3 —
// 3 слизня и ключ, открыть страницу, изменить, удалить; врага и предмет, на которых стоит
// событие, удалить нельзя. Как событие ложится в базу — test/event_db_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/item.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'manual_edit_flow_test.dart' show openMines;

Future<void> choose(WidgetTester t, String dropdown, String option) async {
  await tapButton(t, dropdown);
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

/// Заполняет открытую форму события из приёмки и жмёт «Создать».
Future<void> fillAmbush(WidgetTester t) async {
  await t.enterText(find.byKey(const Key('event-title')), 'Засада у лебёдки');
  await choose(t, 'event-location', 'Штольня №3');
  await tapButton(t, 'event-enemy-add');
  await choose(t, 'event-enemy-0', 'Слизень');
  await t.enterText(find.byKey(const Key('event-enemy-amount-0')), '3');
  await tapButton(t, 'event-item-add');
  await choose(t, 'event-item-0', 'Ключ');
  await tapButton(t, 'event-save');
}

void main() {
  testWidgets('событие: создать в Штольне №3 — 3 слизня и ключ; видно в мире', (
    t,
  ) async {
    final content = await openMines(t);
    final before = checkWorld(await content.snapshotOf(minesId));
    expect(find.text('Событий пока нет'), findsOneWidget);
    await tapButton(t, 'new-event');
    expect(find.text('Новое событие'), findsOneWidget);
    await fillAmbush(t);

    expect(find.text('Новое событие'), findsNothing);
    expect(find.text('Засада у лебёдки'), findsOneWidget);
    final w = await content.snapshotOf(minesId);
    final e = w.events.single;
    expect(w.titles[e.locationId], 'Штольня №3');
    expect(
      [for (final x in e.enemies) '${w.titles[x.characterId]} × ${x.amount}'],
      ['Слизень × 3'],
    );
    expect([for (final id in e.itemIds) w.titles[id]], ['Ключ']);
    // Проверка мира от события не испортилась.
    expect(
      [for (final p in checkWorld(w)) p.message],
      [for (final p in before) p.message],
    );
  });

  testWidgets('событие: без названия и без места не создаётся', (t) async {
    final content = await openMines(t);
    await tapButton(t, 'new-event');
    await tapButton(t, 'event-save');
    expect(find.text('Нужно название события'), findsOneWidget);
    await t.enterText(find.byKey(const Key('event-title')), 'Засада');
    await tapButton(t, 'event-save');
    expect(
      find.text('Выбери место — событие всегда идёт в месте'),
      findsOneWidget,
    );
    await choose(t, 'event-location', 'Штольня №3');
    await tapButton(t, 'event-enemy-add');
    await tapButton(t, 'event-save');
    expect(find.text('Выбери врага'), findsOneWidget);
    await choose(t, 'event-enemy-0', 'Слизень');
    await t.enterText(find.byKey(const Key('event-enemy-amount-0')), '0');
    await tapButton(t, 'event-save');
    expect(find.text('Число врагов — целое от 1'), findsOneWidget);
    expect(await content.events(minesId), isEmpty);
  });

  testWidgets('событие: враг в списке — только с ролью «враг»', (t) async {
    await openMines(t);
    await tapButton(t, 'new-event');
    await tapButton(t, 'event-enemy-add');
    await tapButton(t, 'event-enemy-0');
    expect(find.text('Слизень'), findsWidgets);
    expect(find.text('Бригадир'), findsNothing);
  });

  testWidgets('событие: страница — место, враги с числом, предметы; ячейки '
      'ведут на объекты', (t) async {
    final content = await openMines(t);
    await tapButton(t, 'new-event');
    await fillAmbush(t);
    final slug = (await content.events(minesId)).single.slug;

    await tapButton(t, 'open-$slug');
    expect(find.text('Событие'), findsOneWidget);
    expect(find.text('Штольня №3'), findsOneWidget);
    expect(find.text('× 3'), findsOneWidget);
    expect(find.byKey(const Key('enemy-slizen')), findsOneWidget);
    expect(find.byKey(const Key('event-item-klyuch')), findsOneWidget);
    await tapButton(t, 'enemy-slizen');
    expectTile('Атака', '5');
  });

  testWidgets('событие: изменить число врагов — мир и история; удалить — '
      'события нет', (t) async {
    final content = await openMines(t);
    await tapButton(t, 'new-event');
    await fillAmbush(t);
    final slug = (await content.events(minesId)).single.slug;

    await tapButton(t, 'open-$slug');
    await tapButton(t, 'object-edit');
    expect(find.text('Изменить событие'), findsOneWidget);
    final amount = find.byKey(const Key('event-enemy-amount-0'));
    expect(t.widget<TextField>(amount).controller!.text, '3');
    await t.enterText(amount, '5');
    await tapButton(t, 'event-save');
    expect(find.text('Изменить событие'), findsNothing);
    expect((await content.events(minesId)).single.enemies.single.amount, 5);
    expect(
      content.journal.single.entry.request,
      'Правка вручную: Засада у лебёдки',
    );
    expect(
      [for (final op in content.journal.single.entry.ops) op.type],
      ['event_enemy'],
    );

    // После правки — снова мир: страница открывается уже с новым числом.
    await tapButton(t, 'open-$slug');
    expect(find.text('× 5'), findsOneWidget);
    await tapButton(t, 'object-edit');
    await tapButton(t, 'object-delete');
    expect(await content.events(minesId), isEmpty);
    expect(
      content.journal.last.entry.request,
      'Удаление вручную: Засада у лебёдки',
    );
  });

  testWidgets('врага и предмет, на которых стоит событие, удалить нельзя; '
      'событие убрали — можно', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Крыса и фонарь нужны только событию: других ссылок на них нет.
    final content = await minesContent();
    await content.createCharacter(
      minesId,
      const NewCharacter(
        title: 'Крыса',
        description: '',
        role: Role.enemy,
        locationId: null,
      ),
    );
    await content.createItem(
      minesId,
      const NewItem(
        title: 'Фонарь',
        kind: ItemKind.misc,
        rarity: Rarity.common,
        level: 1,
        price: 5,
      ),
    );
    await pumpApp(t, content: content, assistant: FakeAssistant());
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await tapButton(t, 'new-event');
    await t.enterText(find.byKey(const Key('event-title')), 'Нора');
    await choose(t, 'event-location', 'Рынок');
    await tapButton(t, 'event-enemy-add');
    await choose(t, 'event-enemy-0', 'Крыса');
    await tapButton(t, 'event-item-add');
    await choose(t, 'event-item-0', 'Фонарь');
    await tapButton(t, 'event-save');
    final slug = (await content.events(minesId)).single.slug;

    for (final (object, why) in [
      ('krysa', 'стоит в событии «Нора»'),
      ('fonar', 'лежит в событии «Нора»'),
      ('rynok', 'здесь идёт событие «Нора»'),
    ]) {
      await tapButton(t, 'open-$object');
      await tapButton(t, 'object-edit');
      await tapButton(t, 'object-delete');
      expect(find.textContaining(why), findsOneWidget, reason: object);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
    }
    expect((await content.characters(minesId)).map((c) => c.slug), contains('krysa'));
    expect((await content.items(minesId)).map((i) => i.slug), contains('fonar'));
    expect((await content.locations(minesId)).map((l) => l.slug), contains('rynok'));

    await tapButton(t, 'open-$slug');
    await tapButton(t, 'object-edit');
    await tapButton(t, 'object-delete');
    await tapButton(t, 'open-krysa');
    await tapButton(t, 'object-edit');
    await tapButton(t, 'object-delete');
    expect(
      (await content.characters(minesId)).map((c) => c.slug),
      isNot(contains('krysa')),
    );
  });
}
