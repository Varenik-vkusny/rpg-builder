// Путь автора внутри мира без сети: создаёт объекты и видит их в мире.
// Изоляцию содержимого между авторами в настоящей базе проверяет content_rls_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('автор создаёт локацию и видит её в мире', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    expect(find.text('Локаций пока нет'), findsOneWidget);

    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('location-title')), 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('location-description')),
      'Сырая и тёмная',
    );
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();

    expect(find.text('Штольня №3'), findsOneWidget);
    expect(find.text('Уровни 1–10'), findsOneWidget);
    expect(find.text('Локаций пока нет'), findsNothing);
  });

  testWidgets('локация без названия не создаётся', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();

    expect(find.text('Нужно название локации'), findsOneWidget);
  });

  testWidgets('автор создаёт квестовый предмет и видит его в мире', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    expect(find.text('Предметов пока нет'), findsOneWidget);

    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Ключ от лебёдки');
    await t.tap(find.byKey(const Key('item-kind-quest')));
    await t.pumpAndSettle();
    // У квестового предмета нет ни урона, ни защиты.
    expect(find.byKey(const Key('item-stat')), findsNothing);
    await t.enterText(find.byKey(const Key('item-level')), '2');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();

    expect(find.text('Ключ от лебёдки'), findsOneWidget);
    expect(find.text('Квестовый · Обычный · ур. 2 · 0 зол.'), findsOneWidget);
  });

  testWidgets('предмет-оружие получает урон, редкость и цену', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Кирка');
    await t.tap(find.byKey(const Key('item-rarity-rare')));
    await t.enterText(find.byKey(const Key('item-level')), '3');
    await t.enterText(find.byKey(const Key('item-stat')), '6');
    await t.enterText(find.byKey(const Key('item-price')), '40');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();

    expect(
      find.text('Оружие · Редкий · ур. 3 · урон 6 · 40 зол.'),
      findsOneWidget,
    );
  });

  testWidgets('предмет-оружие без урона не создаётся', (t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Кирка');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();

    expect(find.text('Урон — целое число от 0'), findsOneWidget);
  });

  /// Мир с «Штольней №3» и «Ключом от лебёдки» — как в приёмке.
  Future<void> worldWithShaftAndKey(WidgetTester t) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('location-title')), 'Штольня №3');
    await t.tap(find.byKey(const Key('location-save')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Ключ от лебёдки');
    await t.tap(find.byKey(const Key('item-kind-quest')));
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();
  }

  Future<void> startEnemy(WidgetTester t, String name) async {
    await t.tap(find.byKey(const Key('new-character')));
    await t.pumpAndSettle();
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
    expect(find.text('Персонажей пока нет'), findsOneWidget);

    await startEnemy(t, 'Пепельный слизень');
    await choose(t, const Key('character-location'), 'Штольня №3');
    await t.tap(find.byKey(const Key('loot-add')));
    await t.pumpAndSettle();
    await choose(t, const Key('loot-item-0'), 'Ключ от лебёдки');
    await t.enterText(find.byKey(const Key('loot-chance-0')), '35');
    await t.tap(find.byKey(const Key('character-save')));
    await t.pumpAndSettle();

    expect(find.text('Пепельный слизень'), findsOneWidget);
    expect(
      find.text('Враг · Штольня №3 · роняет: Ключ от лебёдки 35%'),
      findsOneWidget,
    );
  });

  for (final bad in ['0', '100.5', '-3', 'много']) {
    testWidgets('персонаж: шанс добычи «$bad» не принимается', (t) async {
      await worldWithShaftAndKey(t);
      await startEnemy(t, 'Пепельный слизень');
      await t.tap(find.byKey(const Key('loot-add')));
      await t.pumpAndSettle();
      await choose(t, const Key('loot-item-0'), 'Ключ от лебёдки');
      await t.enterText(find.byKey(const Key('loot-chance-0')), bad);
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
    await t.tap(find.byKey(const Key('character-save')));
    await t.pumpAndSettle();

    expect(find.text('Враг · роняет: Ключ от лебёдки 100%'), findsOneWidget);
  });

  testWidgets('персонаж-житель не имеет добычи', (t) async {
    await worldWithShaftAndKey(t);
    await t.tap(find.byKey(const Key('new-character')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('loot-add')), findsNothing);
    await t.enterText(find.byKey(const Key('character-title')), 'Бригадир');
    await choose(t, const Key('character-location'), 'Штольня №3');
    await t.tap(find.byKey(const Key('character-save')));
    await t.pumpAndSettle();

    expect(find.text('Житель · Штольня №3'), findsOneWidget);
  });
}
