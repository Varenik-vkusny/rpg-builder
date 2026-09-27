// Путь автора к квесту без сети: форма квеста и квест в списке мира.
// Запреты и изоляцию квестов в настоящей базе проверяет quest_rls_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';

import 'fakes.dart';

void main() {
  group('квесты', () {
    const worldId = '0-Пепельные копи';

    /// «Пепельные копи» с тем, на что ссылается квест из приёмки:
    /// Бригадир Эрден (житель), Пепельный слизень (враг), ключ, кирка, штольня.
    Future<void> minesWithCrew(WidgetTester t) async {
      final content = FakeContent();
      await pumpApp(t, content: content);
      await signUp(t, 'a@test.dev');
      await createWorld(t, 'Пепельные копи');
      final shaft = await content.createLocation(
        worldId,
        const NewLocation(
          title: 'Штольня №3',
          description: '',
          levelMin: 2,
          levelMax: 4,
        ),
      );
      await content.createItem(
        worldId,
        const NewItem(
          title: 'Ключ от лебёдки',
          kind: ItemKind.quest,
          rarity: Rarity.common,
          level: 2,
          price: 0,
        ),
      );
      await content.createItem(
        worldId,
        const NewItem(
          title: 'Кирка',
          kind: ItemKind.weapon,
          rarity: Rarity.rare,
          level: 3,
          damage: 6,
          price: 40,
        ),
      );
      await content.createCharacter(
        worldId,
        const NewCharacter(
          title: 'Бригадир Эрден',
          description: '',
          role: Role.npc,
          locationId: null,
        ),
      );
      await content.createCharacter(
        worldId,
        NewCharacter(
          title: 'Пепельный слизень',
          description: '',
          role: Role.enemy,
          locationId: shaft.id,
        ),
      );
      await openWorld(t, 'Пепельные копи');
    }

    Future<void> tapKey(WidgetTester t, String key) async {
      await t.ensureVisible(find.byKey(Key(key)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key(key)));
      await t.pumpAndSettle();
    }

    Future<void> pick(WidgetTester t, String dropdown, String option) async {
      await tapKey(t, dropdown);
      await t.tap(find.text(option).last);
      await t.pumpAndSettle();
    }

    /// Список мира строится лениво — раздел «Квесты» внизу, докручиваем.
    Future<void> scrollTo(WidgetTester t, Finder f) =>
        t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

    Future<void> startQuest(WidgetTester t, String title) async {
      await scrollTo(t, find.byKey(const Key('new-quest')));
      await tapKey(t, 'new-quest');
      await t.enterText(find.byKey(const Key('quest-title')), title);
    }

    Future<void> save(WidgetTester t) => tapKey(t, 'quest-save');

    testWidgets('автор создаёт квест — выдающий, шаги, награда', (t) async {
      // Ширина телефона: длинные имена в выпадающих списках не вылезают за край.
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await minesWithCrew(t);
      await scrollTo(t, find.text('Квестов пока нет'));

      await startQuest(t, 'Обвал в третьей штольне');
      await pick(t, 'quest-giver', 'Бригадир Эрден');
      await pick(t, 'step-target-0-talk', 'Бригадир Эрден');
      await tapKey(t, 'step-add');
      await pick(t, 'step-kind-1', 'Убить');
      await pick(t, 'step-target-1-kill', 'Пепельный слизень');
      await t.enterText(find.byKey(const Key('step-amount-1')), '4');
      await tapKey(t, 'step-add');
      await pick(t, 'step-kind-2', 'Собрать');
      await pick(t, 'step-target-2-collect', 'Ключ от лебёдки');
      await t.enterText(find.byKey(const Key('step-amount-2')), '1');
      await tapKey(t, 'reward-add');
      await pick(t, 'reward-0', 'Кирка');
      await save(t);

      await scrollTo(t, find.text('Обвал в третьей штольне'));
      await openObject(t, 'Обвал в третьей штольне');
      for (final line in [
        'Выдаёт: Бригадир Эрден',
        '1. Поговорить: Бригадир Эрден',
        '2. Убить: Пепельный слизень × 4',
        '3. Собрать: Ключ от лебёдки × 1',
        'Награда: Кирка',
      ]) {
        expect(find.text(line), findsOneWidget, reason: line);
      }
    });

    testWidgets('врага нельзя выбрать выдающим', (t) async {
      await minesWithCrew(t);
      await startQuest(t, 'Обвал');
      await tapKey(t, 'quest-giver');

      expect(find.text('Бригадир Эрден'), findsWidgets);
      expect(find.text('Пепельный слизень'), findsNothing);
    });

    testWidgets('убить можно только врага', (t) async {
      await minesWithCrew(t);
      await startQuest(t, 'Обвал');
      await pick(t, 'step-kind-0', 'Убить');
      await tapKey(t, 'step-target-0-kill');

      expect(find.text('Пепельный слизень'), findsWidgets);
      expect(find.text('Бригадир Эрден'), findsNothing);
    });

    testWidgets('без выдающего не создаётся', (t) async {
      await minesWithCrew(t);
      await startQuest(t, 'Обвал');
      await pick(t, 'step-target-0-talk', 'Бригадир Эрден');
      await save(t);

      expect(find.text('Выбери, кто выдаёт квест'), findsOneWidget);
      expect(find.text('Новый квест'), findsOneWidget);
    });

    testWidgets('шаг без цели не создаётся', (t) async {
      await minesWithCrew(t);
      await startQuest(t, 'Обвал');
      await pick(t, 'quest-giver', 'Бригадир Эрден');
      await save(t);

      expect(find.text('У шага 1 не выбрана цель'), findsOneWidget);
    });

    testWidgets('без шагов не создаётся', (t) async {
      await minesWithCrew(t);
      await startQuest(t, 'Обвал');
      await pick(t, 'quest-giver', 'Бригадир Эрден');
      await t.tap(find.byTooltip('Убрать шаг'));
      await t.pumpAndSettle();
      await save(t);

      expect(find.text('Нужен хотя бы один шаг'), findsOneWidget);
    });

    for (final bad in ['0', '-2', 'четыре']) {
      testWidgets('количество «$bad» не принимается', (t) async {
        await minesWithCrew(t);
        await startQuest(t, 'Обвал');
        await pick(t, 'quest-giver', 'Бригадир Эрден');
        await pick(t, 'step-kind-0', 'Убить');
        await pick(t, 'step-target-0-kill', 'Пепельный слизень');
        await t.enterText(find.byKey(const Key('step-amount-0')), bad);
        await save(t);

        expect(
          find.text('Количество в шаге 1 — целое число от 1'),
          findsOneWidget,
        );
      });
    }
  });
}
