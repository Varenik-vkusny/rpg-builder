// Прибор 5е.4 «Строить: связь жестом»: провёл от объекта к объекту — связь нужного вида;
// число — колёсиком, связь видна меткой; квест → житель — меню «Поговорить / Убить». Каждая связь —
// через проверку и историю; несвязуемые пары и повтор — отказ, мир не тронут.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/quest.dart';
import 'package:rpg_builder/map/holst_threads.dart' show ThreadTone;

import 'fakes.dart';
import 'holst_build_test.dart' show build, settle, snack;
import 'holst_fixture.dart';
import 'holst_look_test.dart' show drawnTags, token;

/// Широкий экран: в тестах шрифт шире настоящего, а полка должна быть видна целиком.
const wide = Size(1100, 800);

/// Провести нить от жетона [from] к жетону [to].
Future<void> thread(WidgetTester t, String from, String to) async {
  final a = t.getCenter(token(from)), b = t.getCenter(token(to));
  final g = await t.startGesture(a);
  for (var i = 1; i <= 12; i++) {
    await g.moveTo(Offset.lerp(a, b, i / 12)!);
    await t.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await settle(t);
}

Future<int> sets(FakeContent c) async => c.journal.length;

void main() {
  testWidgets(
    'враг → предмет: колёсико «Шанс», 40% — добыча в мире и в истории',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c, size: wide);
      await build(t);
      final before = await sets(c);
      await thread(t, 'slizen', 'kirka');
      expect(find.byKey(const Key('holst-wheel')), findsOneWidget);
      expect(find.text('Шанс'), findsOneWidget);
      // Пока крутят — на Кирке зелёная метка: кто и с каким числом; нитей нет.
      final pickId = (await c.snapshotOf(holstWorld.id)).items
          .firstWhere((x) => x.slug == 'kirka')
          .id;
      expect(drawnTags(t).tags.single.id, pickId);
      expect(drawnTags(t).tags.single.text, 'Слизень роняет 25%');
      expect(drawnTags(t).tags.single.tone, ThreadTone.isNew);
      // 25% → 40%: три деления вниз.
      await t.drag(
        find.byKey(const Key('holst-wheel-drum')),
        const Offset(0, -144),
      );
      await settle(t);
      expect(drawnTags(t).tags.single.text, 'Слизень роняет 40%');
      expect(await sets(c), before, reason: 'до «Готово» мир не тронут');
      await t.tap(find.byKey(const Key('holst-wheel-done')));
      await settle(t);

      expect(snack(t), 'Связь: Слизень — роняет 40% — Кирка');
      expect(await sets(c), before + 1);
      final w = await c.snapshotOf(holstWorld.id);
      final slime = w.characters.firstWhere((x) => x.slug == 'slizen');
      final pick = w.items.firstWhere((x) => x.slug == 'kirka');
      expect(slime.loot.where((l) => l.itemId == pick.id).single.chance, 40);
      // Новая связь видна и в покое — зелёной меткой на Кирке.
      final fresh = drawnTags(t).tags
          .where((x) => x.tone == ThreadTone.isNew)
          .single;
      expect((fresh.id, fresh.text), (pick.id, 'Слизень роняет 40%'));
      // Метка стоит — значков под ней нет, у соседей значки остались.
      final badges = drawnTags(t).badges;
      expect(badges.where((b) => b.rect == fresh.rect), isEmpty);
      expect(badges, isNotEmpty);
      // «Отменить» — добычи нет.
      await t.tap(find.byKey(const Key('holst-snack-action')));
      await settle(t);
      final back = await c.snapshotOf(holstWorld.id);
      expect(
        back.characters.firstWhere((x) => x.slug == 'slizen').loot,
        hasLength(1),
      );
      expect(drawnTags(t).tags, isEmpty);
    },
  );

  testWidgets(
    'квест → житель: меню «Поговорить / Убить», шаг встал последним',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c, size: wide);
      await build(t);
      await thread(t, 'storozh', 'obval');
      expect(find.byKey(const Key('holst-menu')), findsOneWidget);
      expect(find.text('Обвал → Сторож'), findsOneWidget);
      await t.tap(find.byKey(const Key('holst-menu-talk')));
      await settle(t);
      expect(snack(t), 'Связь: Обвал — поговорить — Сторож');
      final q = (await c.snapshotOf(holstWorld.id)).quests.single;
      expect(q.steps, hasLength(4));
      expect(q.steps.last.kind, StepKind.talk);
      // На Стороже — с кем и какой шаг: «Обвал, шаг 4: поговорить», со значком квеста.
      final tag = drawnTags(t).tags.single;
      expect(tag.text, 'Обвал, шаг 4: поговорить');
      expect(tag.icon, isNotNull);
    },
  );

  testWidgets('событие → предмет: без колёсика, сразу «лежит»', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: wide);
    await build(t);
    await thread(t, 'zasada', 'klyuch_ot_lebedki');
    expect(find.byKey(const Key('holst-wheel')), findsNothing);
    expect(snack(t), 'Связь: Засада — лежит — Ключ от лебёдки');
    final e = (await c.snapshotOf(holstWorld.id)).events.single;
    expect(e.itemIds, hasLength(1));
  });

  testWidgets(
    'житель и житель — не связываются; повтор — «Уже связаны»; мимо — отказ',
    (t) async {
      final c = await ashMines();
      await pumpHolst(t, c, size: wide);
      await build(t);
      final before = await sets(c);
      await thread(t, 'brigadir', 'storozh');
      expect(snack(t), 'Житель и житель не связываются');
      await thread(t, 'zasada', 'slizen');
      expect(snack(t), 'Уже связаны: Засада и Слизень');
      // Отпустили на пустом холсте.
      final a = t.getCenter(token('storozh'));
      final g = await t.startGesture(a);
      await g.moveTo(a + const Offset(120, 0));
      await t.pump();
      await g.moveTo(a + const Offset(260, 0));
      await g.up();
      await settle(t);
      expect(snack(t), 'Отпусти на другом объекте');
      expect(await sets(c), before);
    },
  );

  testWidgets('в «Смотреть» провести нельзя — холст двигается', (t) async {
    final c = await ashMines();
    await pumpHolst(t, c, size: wide);
    final before = await sets(c);
    await thread(t, 'slizen', 'kirka');
    expect(find.byKey(const Key('holst-wheel')), findsNothing);
    expect(await sets(c), before);
  });
}
