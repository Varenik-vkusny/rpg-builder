// Мир «Пепельные копи» как в принятом прототипе холста (design/holst_prototype.html):
// Штольня №3 со Слизнем и Засадой, внутри Забой с Камнеедом; Бараки, Рынок, Лебёдка;
// квест «Обвал», Ключ от лебёдки и Кирка на полке. Холст — прямо, без входа в приложение.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/quest.dart';
import 'package:rpg_builder/map/holst_screen.dart';
import 'package:rpg_builder/ui/theme.dart';
import 'package:rpg_builder/worlds/world.dart';

import 'fakes.dart';

const holstWorld = World(
  id: 'w-ash',
  title: 'Пепельные копи',
  setting: '',
  tone: '',
  levelMin: 1,
  levelMax: 10,
);

Future<Location> _place(
  FakeContent c,
  String title,
  int lo,
  int hi, [
  String? parent,
]) => c.createLocation(
  holstWorld.id,
  NewLocation(
    title: title,
    description: '',
    levelMin: lo,
    levelMax: hi,
    parentId: parent,
  ),
);

Future<Character> _who(
  FakeContent c,
  String title,
  Role role,
  String place, {
  int level = 1,
  List<LootDrop> loot = const [],
}) => c.createCharacter(
  holstWorld.id,
  NewCharacter(
    title: title,
    description: '',
    role: role,
    locationId: place,
    level: level,
    loot: loot,
  ),
);

/// Копи как в прототипе. Возвращает подменённую базу с миром.
Future<FakeContent> ashMines() async {
  final c = FakeContent();
  final w = holstWorld.id;
  final shaft = await _place(c, 'Штольня №3', 3, 5);
  final barracks = await _place(c, 'Бараки', 1, 3);
  final market = await _place(c, 'Рынок', 1, 2);
  final winch = await _place(c, 'Лебёдка', 2, 4);
  final face = await _place(c, 'Забой', 4, 5, shaft.id);
  final key = await c.createItem(
    w,
    const NewItem(
      title: 'Ключ от лебёдки',
      kind: ItemKind.quest,
      rarity: Rarity.common,
      level: 1,
      price: 0,
    ),
  );
  final pick = await c.createItem(
    w,
    const NewItem(
      title: 'Кирка',
      kind: ItemKind.weapon,
      rarity: Rarity.common,
      level: 1,
      damage: 5,
      price: 12,
    ),
  );
  final slime = await _who(
    c,
    'Слизень',
    Role.enemy,
    shaft.id,
    level: 4,
    loot: [LootDrop(itemId: key.id, chance: 35)],
  );
  final brig = await _who(c, 'Бригадир', Role.npc, barracks.id);
  await _who(c, 'Торговка Ива', Role.merchant, market.id);
  await _who(c, 'Сторож', Role.npc, winch.id);
  await _who(c, 'Камнеед', Role.enemy, face.id, level: 5);
  final ambush = await c.createEvent(
    w,
    NewEvent(
      title: 'Засада',
      description: '',
      locationId: shaft.id,
      enemies: [EventEnemy(characterId: slime.id, amount: 3)],
    ),
  );
  await c.createQuest(
    w,
    NewQuest(
      title: 'Обвал',
      description: '',
      giverId: brig.id,
      steps: [
        QuestStep(kind: StepKind.kill, targetId: slime.id, amount: 3),
        QuestStep(kind: StepKind.event, targetId: ambush.id),
        QuestStep(kind: StepKind.collect, targetId: key.id, amount: 1),
      ],
      rewardIds: [pick.id],
    ),
  );
  return c;
}

/// Холст мира на телефоне [size] (по умолчанию 380 × 800).
Future<void> pumpHolst(
  WidgetTester t,
  FakeContent c, {
  Size size = const Size(380, 800),
  GlobalKey? wrap,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final snapshot = await c.snapshotOf(holstWorld.id);
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.dark),
    home: HolstScreen(world: holstWorld, repo: c, snapshot: snapshot),
  );
  await t.pumpWidget(
    wrap == null ? app : RepaintBoundary(key: wrap, child: app),
  );
  await t.pumpAndSettle();
}
