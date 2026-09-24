// Мир «Пепельные копи» на подменённой базе и планы ассистента для тестов.
import 'dart:convert';
import 'dart:io';

import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/quest.dart';

import 'fakes.dart';

/// id первого мира первого автора в FakeWorlds.
const minesId = '0-Пепельные копи';

/// План «штольня затоплена» — общий образец с тестами серверной функции.
Map<String, dynamic> floodPlanJson() =>
    jsonDecode(
          File(
            'supabase/functions/assistant/flood_plan.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

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
    const NewLocation(title: 'Рынок', description: '', levelMin: 1, levelMax: 3),
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
  return c;
}
