// Правка 1 (29.09): страница предмета показывает связи, страница квеста ведёт на объекты.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/ui/parts.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

Future<void> openMines(WidgetTester t) async {
  final content = await minesContent();
  // Предмет без связей: его нельзя получить, и страница должна это сказать.
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
  await pumpApp(t, content: content);
  await signUp(t, 'author@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
}

/// Открывает объект по slug, докрутив список мира до него.
Future<void> open(WidgetTester t, String slug) async {
  await t.scrollUntilVisible(
    find.byKey(Key('open-$slug')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(Key('open-$slug')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('предмет: кто роняет с шансом, в каком квесте нужен', (t) async {
    await openMines(t);
    await open(t, 'klyuch');
    expect(find.text('Роняет: Слизень · 35%'), findsOneWidget);
    expect(find.text('Нужен в квесте: Обвал'), findsOneWidget);
    expect(find.byKey(const Key('item-no-links')), findsNothing);

    await t.tap(find.text('Роняет: Слизень · 35%'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Слизень'), findsOneWidget);
  });

  testWidgets('предмет-награда ведёт на свой квест', (t) async {
    await openMines(t);
    await open(t, 'kirka');
    await t.tap(find.text('Награда за квест: Обвал'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Обвал'), findsOneWidget);
  });

  testWidgets('предмет без связей: одна строка «ни с чем не связан»', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'fonar');
    expect(find.text('Предмет ни с чем не связан'), findsOneWidget);
  });

  testWidgets('квест: выдающий, шаг и награда ведут на свои объекты', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'obval');
    for (final (line, page) in [
      ('Выдаёт: Бригадир', 'Бригадир'),
      ('2. Убить: Слизень × 4', 'Слизень'),
      ('3. Собрать: Ключ × 1', 'Ключ'),
      ('Награда: Кирка', 'Кирка'),
    ]) {
      await t.ensureVisible(find.text(line));
      await t.tap(find.text(line));
      await t.pumpAndSettle();
      expect(find.widgetWithText(AppBar, page), findsOneWidget, reason: line);
      await t.pageBack();
      await t.pumpAndSettle();
    }
  });

  testWidgets('квест: выдающий, каждый шаг и награда — отдельной ячейкой', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'obval');
    for (final line in [
      'Выдаёт: Бригадир',
      '1. Поговорить: Бригадир',
      '2. Убить: Слизень × 4',
      '3. Собрать: Ключ × 1',
      'Награда: Кирка',
    ]) {
      final cell = find.ancestor(
        of: find.text(line),
        matching: find.byWidgetPredicate((w) => w is LinkRow && w.boxed),
      );
      expect(cell, findsOneWidget, reason: line);
    }
  });

  testWidgets('место: имя на обложке; в шапке — когда обложка ушла', (t) async {
    await openMines(t);
    await open(t, 'shtolnya_3');
    // Низкое окно — чтобы страницу места можно было прокрутить за обложку.
    t.view.physicalSize = const Size(360, 300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpAndSettle();
    final inBar = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Штольня №3'),
    );
    expect(inBar, findsNothing, reason: 'наверху имя только на обложке');
    expect(find.text('Штольня №3'), findsOneWidget);

    await t.drag(find.byType(ListView).last, const Offset(0, -220));
    await t.pumpAndSettle();
    expect(inBar, findsOneWidget, reason: 'обложка ушла — имя в шапке');
  });
}
