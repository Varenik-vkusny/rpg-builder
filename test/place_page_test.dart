// Страница места (5а.2): путь «Копи › Штольня №3», вложенные места, «кто здесь»
// по всей глубине; вложенное место открывается со страницы родителя.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/location.dart';

import 'fakes.dart';
import 'object_links_test.dart' show open;

const worldId = '0-Пепельные копи';

/// Копи › Штольня №3 › Забой и «Рынок» рядом; по жителю в каждом месте.
Future<FakeContent> nestedMines() async {
  final c = FakeContent();
  Future<Location> place(String title, [Location? parent]) =>
      c.createLocation(
        worldId,
        NewLocation(
          title: title,
          description: '',
          levelMin: 1,
          levelMax: 5,
          parentId: parent?.id,
        ),
      );
  Future<void> who(String title, Location l) => c.createCharacter(
    worldId,
    NewCharacter(
      title: title,
      description: '',
      role: Role.npc,
      locationId: l.id,
    ),
  );
  final kopi = await place('Копи');
  final shaft = await place('Штольня №3', kopi);
  final face = await place('Забой', shaft);
  final market = await place('Рынок');
  await who('Бригадир', kopi);
  await who('Лампщица', shaft);
  await who('Забойщик', face);
  await who('Торговка', market);
  return c;
}

Future<void> openWorldOf(WidgetTester t, FakeContent c) async {
  await pumpApp(t, content: c);
  await signUp(t, 'author@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
}

List<String> texts(Finder f) => [
  for (final e in f.evaluate()) (e.widget as Text).data ?? '',
];

void main() {
  testWidgets('Копи: вложенные места и все жители по глубине', (t) async {
    await openWorldOf(t, await nestedMines());
    await open(t, 'kopi');

    expect(find.byKey(const Key('inner-shtolnya_3')), findsOneWidget);
    // Только прямые вложенные: забой — внутри штольни, не в копях.
    expect(find.byKey(const Key('inner-zaboy')), findsNothing);
    expect(find.text('Кто здесь · 3'), findsOneWidget);
    for (final s in ['brigadir', 'lampshchitsa', 'zaboyshchik']) {
      expect(find.byKey(Key('who-$s')), findsOneWidget, reason: s);
    }
    expect(find.byKey(const Key('who-torgovka')), findsNothing);
    // Место верхнего уровня — без строки пути.
    expect(find.byKey(const Key('place-path')), findsNothing);
  });

  testWidgets('штольня: путь сверху, открывается из копей', (t) async {
    await openWorldOf(t, await nestedMines());
    await open(t, 'kopi');
    await t.ensureVisible(find.byKey(const Key('inner-shtolnya_3')));
    await t.tap(find.byKey(const Key('inner-shtolnya_3')));
    await t.pumpAndSettle();

    expect(
      texts(
        find.descendant(
          of: find.byKey(const Key('place-path')),
          matching: find.byType(Text),
        ),
      ),
      ['Копи › Штольня №3'],
    );
    expect(find.text('Кто здесь · 2'), findsOneWidget);
    expect(find.byKey(const Key('inner-zaboy')), findsOneWidget);
  });

  testWidgets('житель забоя: путь до его места целиком', (t) async {
    await openWorldOf(t, await nestedMines());
    await open(t, 'zaboy');
    await t.ensureVisible(find.byKey(const Key('who-zaboyshchik')));
    await t.tap(find.byKey(const Key('who-zaboyshchik')));
    await t.pumpAndSettle();

    expect(find.text('Копи › Штольня №3 › Забой'), findsOneWidget);
  });
}
