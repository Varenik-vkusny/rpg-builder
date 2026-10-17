// Прибор 5е.6 «Менять: план на холсте». Фраза → план тем же путём, что на экране
// ассистента; до 6 изменений проступают на холсте по шагу, больше — список с «показать
// на холсте»; изменения внутри места — метка на двери; «Применить» — одной транзакцией.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/map/holst_parts.dart';
import 'package:rpg_builder/map/holst_plan.dart';
import 'package:rpg_builder/map/holst_threads.dart' show ThreadTone;

import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'holst_build_test.dart' show settle, snack;
import 'holst_fixture.dart';
import 'holst_look_test.dart' show token;

Finder k(String key) => find.byKey(Key(key));

String text(WidgetTester t, String key) => t.widget<Text>(k(key)).data!;

/// «Пепельные копи» из приёмки (под план «затопи штольню»); внутри Штольни — Забой.
Future<FakeContent> mines() async {
  final c = FakeContent();
  await fillMines(c, holstWorld.id);
  final shaft = (await c.locations(holstWorld.id))
      .firstWhere((l) => l.slug == 'shtolnya_3');
  await c.createLocation(
    holstWorld.id,
    NewLocation(
      title: 'Забой',
      description: '',
      levelMin: 2,
      levelMax: 4,
      parentId: shaft.id,
    ),
  );
  return c;
}

/// Ввести фразу про Штольню и попросить план.
Future<void> ask(WidgetTester t) async {
  await t.tap(k('holst-mode-change'));
  await t.pumpAndSettle();
  expect(text(t, 'holst-scope'), 'Нажми место или объект');
  final head = t.getRect(k('hplace-shtolnya_3'));
  await t.tapAt(head.topLeft + const Offset(40, 16));
  await t.pumpAndSettle();
  expect(text(t, 'holst-scope'), 'Штольня №3');
  await t.enterText(k('holst-phrase'), 'затопи её, слизни там жить не могут');
  await t.tap(k('holst-ask'));
  await t.pump();
}

/// План на каждую попытку: новые предупреждения на копии отправляют план на
/// исправление (до двух раз) — подменённый ассистент отвечает тем же планом.
FakeAssistant everyTry(Plan p) =>
    FakeAssistant([proposal(p), proposal(p), proposal(p)]);

/// Семь новых врагов в Штольне — длиннее показа по шагу.
Plan sevenEnemies() {
  final op = floodPlanJson()['ops'][1] as Map<String, dynamic>;
  return Plan.fromJson({
    'summary': 'семь врагов',
    'ops': [
      for (var i = 1; i <= 7; i++)
        {
          ...op,
          'slug': 'vrag_$i',
          'fields': {
            ...op['fields'] as Map<String, dynamic>,
            'title': 'Враг $i',
            'location': i == 7 ? 'zaboy' : 'shtolnya_3',
          },
        },
    ],
  });
}

void main() {
  testWidgets(
    'план из 5 изменений проступает по шагу, «Применить» — в мире и в истории',
    (t) async {
      final c = await mines();
      await pumpHolst(t, c, assistant: everyTry(floodPlan()));
      await ask(t);
      expect(text(t, 'holst-plan-title'), 'План · 5 изменений');
      // По шагу: строки и объекты появляются не сразу.
      await t.pump(const Duration(milliseconds: 700));
      expect(text(t, 'holst-plan-check'), startsWith('Строю план ·'));
      expect(t.widget<FilledButton>(k('holst-plan-apply')).onPressed, isNull);
      await settle(t);
      await t.pump(const Duration(seconds: 3));
      expect(text(t, 'holst-plan-check'), startsWith('Проверка:'));
      // Утопленник — новый, зелёный; Штольня — изменена; в мире пока ничего.
      final drowned = find.descendant(
        of: token('utoplennik'),
        matching: find.byType(TokenTile),
      );
      expect(t.widget<TokenTile>(drowned).mark, Mark.isNew);
      expect(t.widget<PlaceCard>(k('hplace-shtolnya_3')).mark, Mark.changed);
      expect(
        (await c.snapshotOf(holstWorld.id)).characters
            .any((x) => x.slug == 'utoplennik'),
        isFalse,
      );

      await t.tap(k('holst-plan-apply'));
      await settle(t);
      expect(snack(t), 'План применён: 5 изменений');
      expect(c.changeSets.single.status, 'applied');
      final w = await c.snapshotOf(holstWorld.id);
      expect(w.characters.any((x) => x.slug == 'utoplennik'), isTrue);
      expect(find.byKey(const Key('holst-plan')), findsNothing);

      // «Откатить» — набор откачен, Утопленника нет.
      await t.tap(k('holst-snack-action'));
      await settle(t);
      expect(
        (await c.snapshotOf(holstWorld.id)).characters
            .any((x) => x.slug == 'utoplennik'),
        isFalse,
      );
    },
  );

  testWidgets('«Отклонить» — в журнал, мир не тронут, холст как был', (
    t,
  ) async {
    final c = await mines();
    await pumpHolst(t, c, assistant: everyTry(floodPlan()));
    await ask(t);
    await t.pump(const Duration(seconds: 4));
    await t.tap(k('holst-plan-reject'));
    await settle(t);
    expect(snack(t), 'План отклонён');
    expect(c.changeSets.single.status, 'rejected');
    expect(token('utoplennik'), findsNothing);
    expect(t.widget<PlaceCard>(k('hplace-shtolnya_3')).mark, Mark.none);
  });

  testWidgets(
    'больше 6 изменений — сразу список; «показать на холсте»; метка на двери',
    (t) async {
      final c = await mines();
      await pumpHolst(
        t,
        c,
        size: const Size(380, 900),
        assistant: everyTry(sevenEnemies()),
      );
      await ask(t);
      await settle(t);
      expect(text(t, 'holst-plan-title'), 'План · 7 изменений');
      expect(text(t, 'holst-plan-check'), startsWith('Проверка:'));
      // Седьмой враг — в Забое, уровнем ниже: на двери метка.
      expect(
        find.descendant(
          of: k('hdoor-zaboy'),
          matching: find.text('внутри 1 изменение'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byTooltip('Показать на холсте').first);
      await settle(t);
      expect(k('holst-plan-list'), findsOneWidget);
      expect(k('holst-plan-row-0'), findsNothing);
      await t.tap(k('holst-plan-list'));
      await settle(t);
      expect(k('holst-plan-row-0'), findsOneWidget);
    },
  );

  testWidgets('план с ошибкой проверки — «Применить» заперто', (t) async {
    final c = await mines();
    // Шаг правит персонажа, которого нет в мире, — ошибка на копии.
    final op = floodPlanJson()['ops'][0] as Map<String, dynamic>;
    final broken = Plan.fromJson({
      'summary': 'ошибка',
      'ops': [
        {...op, 'type': 'character', 'slug': 'nikto'},
      ],
    });
    await pumpHolst(t, c, assistant: everyTry(broken));
    await ask(t);
    await settle(t);
    await t.pump(const Duration(seconds: 2));
    expect(text(t, 'holst-plan-check'), isNot(startsWith('Проверка: ошибок 0')));
    expect(t.widget<FilledButton>(k('holst-plan-apply')).onPressed, isNull);
    await t.tap(k('holst-plan-apply'));
    await settle(t);
    expect(c.changeSets, isEmpty);
  });

  testWidgets('без области «План» заперт', (t) async {
    final c = await mines();
    await pumpHolst(t, c);
    await t.tap(k('holst-mode-change'));
    await t.pumpAndSettle();
    await t.enterText(k('holst-phrase'), 'что-нибудь');
    await t.pump();
    expect(t.widget<FilledButton>(k('holst-ask')).onPressed, isNull);
  });

  test('строки плана: новое — одной строкой, изменённое — по полю', () async {
    final c = await mines();
    final w = await c.snapshotOf(holstWorld.id);
    final (copy, ops) = applyToCopy(w, floodPlan());
    final rows = planRows(ops, copy);
    String line(PlanRow r) => '${r.title} · ${r.field}: ${r.was} → ${r.now}';
    expect(rows.map(line), [
      'Штольня №3 · описание: обвалившаяся выработка → затоплена по пояс',
      'Утопленник · новое: — → Штольня №3 · ур. 3',
      'Слизень · добыча: Ключ 35% → —',
      'Утопленник · добыча: — → Ключ 35%',
      'Обвал · шаг 2: Убить: Слизень × 4 → Убить: Утопленник × 3',
    ]);
    final shaft = rows.firstWhere((r) => r.title == 'Штольня №3');
    expect(shaft.field, 'описание');
    expect(shaft.now, 'затоплена по пояс');
  });

  test('нити плана: две связи одной пары не путаются', () async {
    final c = await mines();
    final w = await c.snapshotOf(holstWorld.id);
    final copy = applyToCopy(w, floodPlan()).$1;
    final tones = planThreads(w, copy);
    final quest = copy.quests.single.id;
    final giver = copy.quests.single.giverId!;
    // У квеста с бригадиром «выдаёт» и «поговорить» — план их не трогал.
    expect(tones['$quest>$giver'], isNull);
    final drowned = copy.characters
        .firstWhere((x) => x.slug == 'utoplennik')
        .id;
    expect(tones['$quest>$drowned'], ThreadTone.isNew);
  });
}
