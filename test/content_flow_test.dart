// Путь автора внутри мира без сети: создаёт объекты и видит их в мире.
// Изоляцию содержимого между авторами в настоящей базе проверяет content_rls_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'fakes.dart';

/// Раздел «Предметы» стоит ниже мест и событий и на экран теста не попадает:
/// экран повыше — и ленивый список мира построен целиком.
Future<void> toItems(WidgetTester t) async {
  t.view.physicalSize = const Size(800, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('автор создаёт локацию и видит её в мире', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    expect(find.text('Локаций пока нет'), findsOneWidget);

    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('location-description')),
      'Сырая и тёмная',
    );
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();

    expect(inWorld('Штольня №3'), findsOneWidget);
    expect(find.text('ур. 1–10'), findsOneWidget);
    expect(find.text('Локаций пока нет'), findsNothing);
  });

  testWidgets('локация без названия не создаётся', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await tapButton(t, 'new-location');
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();

    expect(find.text('Нужно название локации'), findsOneWidget);
  });

  testWidgets('автор создаёт квестовый предмет и видит его в мире', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await toItems(t);
    expect(find.text('Предметов пока нет'), findsOneWidget);

    await tapButton(t, 'new-item');
    await t.enterText(find.byKey(const Key('item-title')), 'Ключ от лебёдки');
    await t.tap(find.byKey(const Key('item-kind-quest')));
    await t.pumpAndSettle();
    // У квестового предмета нет ни урона, ни защиты.
    expect(find.byKey(const Key('item-stat')), findsNothing);
    await t.enterText(find.byKey(const Key('item-level')), '2');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();

    expect(inWorld('Ключ от лебёдки'), findsOneWidget);
    await openObject(t, 'Ключ от лебёдки');
    // Вид и редкость — отдельные плашки, не склейка «Квестовый · Обычный».
    expect(find.text('Квестовый'), findsOneWidget);
    expect(find.text('Обычный'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    expectTile('Уровень', '2');
    expectTile('Цена', '0');
  });

  testWidgets('предмет-оружие получает урон, редкость и цену', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await toItems(t);
    await tapButton(t, 'new-item');
    await t.enterText(find.byKey(const Key('item-title')), 'Кирка');
    await t.tap(find.byKey(const Key('item-rarity-rare')));
    await t.enterText(find.byKey(const Key('item-level')), '3');
    await t.enterText(find.byKey(const Key('item-stat')), '6');
    await t.enterText(find.byKey(const Key('item-price')), '40');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();

    await openObject(t, 'Кирка');
    expect(find.text('Оружие'), findsOneWidget);
    expect(find.text('Редкий'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    expectTile('Уровень', '3');
    expectTile('Урон', '6');
    expectTile('Цена', '40');
  });

  testWidgets('предмет-оружие без урона не создаётся', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await toItems(t);
    await tapButton(t, 'new-item');
    await t.enterText(find.byKey(const Key('item-title')), 'Кирка');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();

    expect(find.text('Урон — целое число от 0'), findsOneWidget);
  });

  /// Мир с «Штольней №3» и «Ключом от лебёдки» — как в приёмке.
  Future<void> worldWithShaftAndKey(WidgetTester t) async {
    // Форма персонажа с добычей выше стандартных 600 точек теста.
    t.view.physicalSize = const Size(800, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'Штольня №3');
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();
    await tapButton(t, 'new-item');
    await t.enterText(find.byKey(const Key('item-title')), 'Ключ от лебёдки');
    await t.tap(find.byKey(const Key('item-kind-quest')));
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();
  }

  Future<void> startEnemy(WidgetTester t, String name) async {
    await tapButton(t, 'new-character');
    await t.enterText(find.byKey(const Key('character-title')), name);
    await t.tap(find.byKey(const Key('character-role-enemy')));
    await t.pumpAndSettle();
  }

  Future<void> choose(WidgetTester t, Key dropdown, String option) async {
    await t.tap(find.byKey(dropdown));
    await t.pumpAndSettle();
    await t.tap(find.text(option).last);
    await t.pumpAndSettle();
  }

  testWidgets('персонаж-враг в локации роняет ключ с шансом 35%', (t) async {
    await worldWithShaftAndKey(t);
    await t.scrollUntilVisible(
      find.text('Персонажей пока нет'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Персонажей пока нет'), findsOneWidget);

    await startEnemy(t, 'Пепельный слизень');
    await choose(t, const Key('character-location'), 'Штольня №3');
    await t.tap(find.byKey(const Key('loot-add')));
    await t.pumpAndSettle();
    await choose(t, const Key('loot-item-0'), 'Ключ от лебёдки');
    await t.enterText(find.byKey(const Key('loot-chance-0')), '35');
    await t.ensureVisible(find.byKey(const Key('character-save')));
    await t.tap(find.byKey(const Key('character-save')));
    await t.pumpAndSettle();

    expect(find.text('Пепельный слизень'), findsOneWidget);
    await openObject(t, 'Пепельный слизень');
    expect(find.text('Враг'), findsOneWidget);
    expect(find.text('Штольня №3'), findsOneWidget);
    expectTile('Уровень', '1');
    expectTile('Здоровье', '10');
    expectTile('Атака', '0');
    expectLoot('Ключ от лебёдки', '35%');
  });

  // Найдено демо-снимками 25.11: на узком экране выбранный предмет добычи
  // («Ключ от лебёдки») вылезал за край строки — жёлто-чёрная полоса.
  testWidgets('добыча: длинное название на телефоне 360 не вылезает за край', (
    t,
  ) async {
    await worldWithShaftAndKey(t);
    await startEnemy(t, 'Пепельный слизень');
    t.view.physicalSize = const Size(360, 800);
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('loot-add')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('loot-add')));
    await t.pumpAndSettle();
    await choose(t, const Key('loot-item-0'), 'Ключ от лебёдки');
    expect(t.takeException(), isNull);
    // Не влезло — многоточие, а не обрубок «Ключ от» (будто другое название).
    final shown = t.widget<Text>(
      find
          .descendant(
            of: find.byKey(const Key('loot-item-0')),
            matching: find.text('Ключ от лебёдки'),
          )
          .first,
    );
    expect(shown.overflow, TextOverflow.ellipsis);
    expect(shown.maxLines, 1);
  });

  for (final bad in ['0', '100.5', '-3', 'много']) {
    testWidgets('персонаж: шанс добычи «$bad» не принимается', (t) async {
      await worldWithShaftAndKey(t);
      await startEnemy(t, 'Пепельный слизень');
      await t.tap(find.byKey(const Key('loot-add')));
      await t.pumpAndSettle();
      await choose(t, const Key('loot-item-0'), 'Ключ от лебёдки');
      await t.enterText(find.byKey(const Key('loot-chance-0')), bad);
      await t.ensureVisible(find.byKey(const Key('character-save')));
      await t.tap(find.byKey(const Key('character-save')));
      await t.pumpAndSettle();

      expect(
        find.text('Шанс добычи — больше 0 и не больше 100'),
        findsOneWidget,
      );
      expect(find.text('Новый персонаж'), findsOneWidget);
    });
  }

  testWidgets('персонаж: шанс ровно 100% принимается', (t) async {
    await worldWithShaftAndKey(t);
    await startEnemy(t, 'Бригадир-призрак');
    await t.tap(find.byKey(const Key('loot-add')));
    await t.pumpAndSettle();
    await choose(t, const Key('loot-item-0'), 'Ключ от лебёдки');
    await t.enterText(find.byKey(const Key('loot-chance-0')), '100');
    await t.ensureVisible(find.byKey(const Key('character-save')));
    await t.tap(find.byKey(const Key('character-save')));
    await t.pumpAndSettle();

    await openObject(t, 'Бригадир-призрак');
    expect(find.text('Враг'), findsOneWidget);
    expectTile('Уровень', '1');
    expectLoot('Ключ от лебёдки', '100%');
    expect(find.byKey(const Key('object-edit')), findsOneWidget);
  });

  testWidgets('персонаж-житель не имеет добычи', (t) async {
    await worldWithShaftAndKey(t);
    await tapButton(t, 'new-character');
    expect(find.byKey(const Key('loot-add')), findsNothing);
    await t.enterText(find.byKey(const Key('character-title')), 'Бригадир');
    await choose(t, const Key('character-location'), 'Штольня №3');
    await t.ensureVisible(find.byKey(const Key('character-save')));
    await t.tap(find.byKey(const Key('character-save')));
    await t.pumpAndSettle();

    await openObject(t, 'Бригадир');
    expect(find.text('Житель'), findsOneWidget);
    expect(find.text('Штольня №3'), findsOneWidget);
    expectTile('Уровень', '1');
    expectTile('Здоровье', '10');
    expectTile('Атака', '0');
    expect(find.text('Добыча'), findsNothing);
  });

  testWidgets('персонаж-враг: уровень 3, здоровье 30, атака 14', (t) async {
    await worldWithShaftAndKey(t);
    await startEnemy(t, 'Утопленник');
    await t.enterText(find.byKey(const Key('character-level')), '3');
    await t.enterText(find.byKey(const Key('character-hp')), '30');
    await t.enterText(find.byKey(const Key('character-attack')), '14');
    await t.ensureVisible(find.byKey(const Key('character-save')));
    await t.tap(find.byKey(const Key('character-save')));
    await t.pumpAndSettle();

    await openObject(t, 'Утопленник');
    expect(find.text('Враг'), findsOneWidget);
    expectTile('Уровень', '3');
    expectTile('Здоровье', '30');
    expectTile('Атака', '14');
  });

  for (final (field, bad, message) in [
    ('character-level', '0', 'Уровень — целое от 1'),
    ('character-hp', '0', 'Здоровье — целое от 1'),
    ('character-attack', '-2', 'Атака — целое от 0'),
    ('character-attack', 'много', 'Атака — целое от 0'),
  ]) {
    testWidgets(
      'персонаж: уровень, здоровье, атака — $field «$bad» не принимается',
      (t) async {
        await worldWithShaftAndKey(t);
        await startEnemy(t, 'Утопленник');
        await t.enterText(find.byKey(Key(field)), bad);
        await t.ensureVisible(find.byKey(const Key('character-save')));
        await t.tap(find.byKey(const Key('character-save')));
        await t.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
        expect(find.text('Новый персонаж'), findsOneWidget);
      },
    );
  }
}
