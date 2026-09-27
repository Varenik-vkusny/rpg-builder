// Мир «Пепельные копи» на подменённой базе и планы ассистента для тестов.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_cards.dart';
import 'package:rpg_builder/ui/parts.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/quest.dart';

import 'fakes.dart';

/// id первого мира первого автора в FakeWorlds.
const minesId = '0-Пепельные копи';

/// План «штольня затоплена» — общий образец с тестами серверной функции.
Map<String, dynamic> floodPlanJson() => jsonDecode(
  File('supabase/functions/assistant/flood_plan.json').readAsStringSync(),
) as Map<String, dynamic>;

Plan floodPlan() => Plan.fromJson(floodPlanJson());

/// Просьба «затопи штольню» так, как её получит серверная функция.
Map<String, dynamic> floodRequestJson() => const ProposeRequest(
  worldId: minesId,
  scope: Scope(ScopeType.location, 'shtolnya_3'),
  request: 'затопи её, слизни там жить не могут',
).toJson();

Proposal proposal(Plan plan) =>
    Proposal(plan, inputTokens: 1000, outputTokens: 200);

/// «Пепельные копи» из приёмки: Штольня №3 (2–4), Рынок, ключ, кирка,
/// слизень (роняет ключ 35%), бригадир, квест «Обвал в третьей штольне».
Future<FakeContent> minesContent() async {
  final c = FakeContent();
  await fillMines(c, minesId);
  return c;
}

/// Наполняет мир [worldId] «Пепельными копями» — в подменённой или настоящей базе.
Future<void> fillMines(ContentRepo c, String minesId) async {
  final shaft = await c.createLocation(
    minesId,
    const NewLocation(
      title: 'Штольня №3',
      description: 'обвалившаяся выработка',
      levelMin: 2,
      levelMax: 4,
    ),
  );
  await c.createLocation(
    minesId,
    const NewLocation(
      title: 'Рынок',
      description: '',
      levelMin: 1,
      levelMax: 3,
    ),
  );
  final key = await c.createItem(
    minesId,
    const NewItem(
      title: 'Ключ',
      kind: ItemKind.quest,
      rarity: Rarity.common,
      level: 2,
      price: 0,
    ),
  );
  final pick = await c.createItem(
    minesId,
    const NewItem(
      title: 'Кирка',
      kind: ItemKind.weapon,
      rarity: Rarity.rare,
      level: 3,
      damage: 6,
      price: 40,
    ),
  );
  final foreman = await c.createCharacter(
    minesId,
    const NewCharacter(
      title: 'Бригадир',
      description: '',
      role: Role.npc,
      locationId: null,
    ),
  );
  final slime = await c.createCharacter(
    minesId,
    NewCharacter(
      title: 'Слизень',
      description: '',
      role: Role.enemy,
      locationId: shaft.id,
      level: 2,
      hp: 12,
      attack: 5,
      loot: [LootDrop(itemId: key.id, chance: 35)],
    ),
  );
  await c.createQuest(
    minesId,
    NewQuest(
      title: 'Обвал',
      description: '',
      giverId: foreman.id,
      steps: [
        QuestStep(kind: StepKind.talk, targetId: foreman.id),
        QuestStep(kind: StepKind.kill, targetId: slime.id, amount: 4),
        QuestStep(kind: StepKind.collect, targetId: key.id, amount: 1),
      ],
      rewardIds: [pick.id],
    ),
  );
}

/// Мир «Пепельные копи» открыт, экран ассистента открыт.
Future<(FakeContent, FakeAssistant)> openAssistant(
  WidgetTester t, [
  FakeAssistant? assistant,
  FakeContent? base,
]) async {
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final content = base ?? await minesContent();
  if (base != null) await fillMines(base, minesId);
  // Три одинаковых ответа: план и два исправления (атака 14 так и остаётся).
  final a =
      assistant ??
      FakeAssistant(List.generate(3, (_) => proposal(floodPlan())));
  await pumpApp(t, content: content, assistant: a);
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  await t.tap(find.byKey(const Key('assistant-open')));
  await t.pumpAndSettle();
  return (content, a);
}

/// Выбирает область и пишет просьбу.
Future<void> ask(
  WidgetTester t, {
  String type = 'location',
  String? object = 'Штольня №3',
  String request = 'затопи её, слизни там жить не могут',
}) async {
  await t.tap(find.byKey(Key('scope-type-$type')));
  await t.pumpAndSettle();
  if (object != null) {
    await t.tap(find.byKey(Key('scope-object-$type')));
    await t.pumpAndSettle();
    await t.tap(find.text(object).last);
    await t.pumpAndSettle();
  }
  await t.enterText(find.byKey(const Key('assistant-request')), request);
  await t.tap(find.byKey(const Key('assistant-propose')));
  await t.pumpAndSettle();
}

/// На экране плана поле показано как «было → стало» (null — нет значения).
void expectChange(String label, String? before, String? after) => expect(
  find.byWidgetPredicate(
    (w) =>
        w is BeforeAfter &&
        w.label == label &&
        w.before == before &&
        w.after == after,
  ),
  findsOneWidget,
  reason: '$label: $before → $after',
);

/// На экране плана есть карточка операции [title] и на ней видно название [name].
void expectOp(String title, String name) => expect(
  find.descendant(
    of: find.byWidgetPredicate((w) => w is OpCard && w.result.title == title),
    matching: find.text(name),
  ),
  // У новой карточки название видно и в шапке, и в поле «Название».
  findsWidgets,
  reason: title,
);

/// Открывает шторку проблем плана.
Future<void> openVerdict(WidgetTester t) async {
  await t.tap(find.byKey(const Key('plan-verdict')));
  await t.pumpAndSettle();
}
