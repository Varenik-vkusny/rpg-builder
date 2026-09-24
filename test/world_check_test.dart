// Правила проверки мира на снимке в памяти — без экрана и без базы.
// База ошибок не пускает, поэтому каждое правило-ошибку доказывает только этот тест.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/warning_rules.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/quest.dart';

const shaft = Location(
  id: 'loc-shaft',
  slug: 'shtolnya_3',
  title: 'Штольня №3',
  description: '',
  levelMin: 2,
  levelMax: 4,
);

const key = Item(
  id: 'item-key',
  slug: 'klyuch',
  title: 'Ключ от лебёдки',
  kind: ItemKind.quest,
  rarity: Rarity.common,
  level: 2,
  damage: null,
  defense: null,
  price: 0,
);

const pick = Item(
  id: 'item-pick',
  slug: 'kirka',
  title: 'Кирка',
  kind: ItemKind.weapon,
  rarity: Rarity.rare,
  level: 3,
  damage: 6,
  defense: null,
  price: 40,
);

const foreman = Character(
  id: 'char-foreman',
  slug: 'brigadir',
  title: 'Бригадир Эрден',
  description: '',
  role: Role.npc,
  locationId: null,
  loot: [],
);

const slime = Character(
  id: 'char-slime',
  slug: 'sliz',
  title: 'Пепельный слизень',
  description: '',
  role: Role.enemy,
  locationId: 'loc-shaft',
  loot: [LootDrop(itemId: 'item-key', chance: 35)],
);

const steps = [
  QuestStep(kind: StepKind.talk, targetId: 'char-foreman'),
  QuestStep(kind: StepKind.kill, targetId: 'char-slime', amount: 4),
  QuestStep(kind: StepKind.collect, targetId: 'item-key', amount: 1),
  QuestStep(kind: StepKind.visit, targetId: 'loc-shaft'),
];

Quest quest({
  String? giverId = 'char-foreman',
  List<QuestStep> steps = steps,
  List<String> rewardIds = const ['item-pick'],
}) => Quest(
  id: 'quest-obval',
  slug: 'obval',
  title: 'Обвал в третьей штольне',
  description: '',
  giverId: giverId,
  steps: steps,
  rewardIds: rewardIds,
);

/// «Пепельные копи» из приёмки 2.4 — мир без ошибок.
WorldSnapshot mines({
  List<Character> characters = const [foreman, slime],
  Quest? q,
}) => WorldSnapshot(
  locations: const [shaft],
  items: const [key, pick],
  characters: characters,
  quests: [q ?? quest()],
);

List<String> errors(WorldSnapshot w) => [
  for (final p in checkWorld(w))
    if (p.severity == Severity.error) p.rule,
];

/// Предупреждения одного правила — сообщениями.
List<String> warnings(WorldSnapshot w, String rule) => [
  for (final p in checkWorld(w))
    if (p.severity == Severity.warning && p.rule == rule) p.message,
];

/// Оружие, которое выдаётся наградой, — чтобы не мешало правило «нельзя получить».
Item weapon(
  String id, {
  String title = 'Меч',
  Rarity rarity = Rarity.common,
  int level = 2,
  int damage = 5,
  int price = 10,
}) => Item(
  id: id,
  slug: id,
  title: title,
  kind: ItemKind.weapon,
  rarity: rarity,
  level: level,
  damage: damage,
  defense: null,
  price: price,
);

/// Мир из приёмки плюс [extra] предметов, все они — награда квеста.
WorldSnapshot withItems(List<Item> extra) => WorldSnapshot(
  locations: const [shaft],
  items: [key, pick, ...extra],
  characters: const [foreman, slime],
  quests: [
    quest(rewardIds: ['item-pick', for (final i in extra) i.id]),
  ],
);

void main() {
  group('проверка мира: ошибки', () {
    test('в целом мире ошибок нет', () {
      expect(errors(mines()), isEmpty);
    });

    test('квест без выдающего — ошибка', () {
      final p = checkWorld(mines(q: quest(giverId: null)));
      expect(p.map((x) => x.rule), ['quest_no_giver']);
      expect(p.single.objectId, 'quest-obval');
      expect(p.single.message, contains('Обвал в третьей штольне'));
    });

    test('квест без шагов — ошибка', () {
      expect(errors(mines(q: quest(steps: const []))), ['quest_no_steps']);
    });

    test('выдающий, которого нет в мире, — битая ссылка', () {
      expect(errors(mines(q: quest(giverId: 'char-nobody'))), ['broken_link']);
    });

    test('шаг с целью, которой нет в мире, — битая ссылка', () {
      final broken = [
        ...steps,
        const QuestStep(
          kind: StepKind.kill,
          targetId: 'char-nobody',
          amount: 1,
        ),
      ];
      final p = checkWorld(mines(q: quest(steps: broken)));
      expect(p.map((x) => x.rule), ['broken_link']);
      expect(p.single.message, contains('шаг 5'));
    });

    test('шаг «собрать» смотрит в предметы, а не в персонажей', () {
      // id есть в мире, но это персонаж: собрать его нельзя.
      final wrongKind = [
        const QuestStep(
          kind: StepKind.collect,
          targetId: 'char-slime',
          amount: 1,
        ),
      ];
      expect(errors(mines(q: quest(steps: wrongKind))), ['broken_link']);
    });

    test('награда, которой нет в мире, — битая ссылка', () {
      expect(errors(mines(q: quest(rewardIds: const ['item-nobody']))), [
        'broken_link',
      ]);
    });

    test('персонаж в несуществующей локации и с несуществующей добычей', () {
      const lost = Character(
        id: 'char-lost',
        slug: 'lost',
        title: 'Потерянный',
        description: '',
        role: Role.enemy,
        locationId: 'loc-nowhere',
        loot: [LootDrop(itemId: 'item-nobody', chance: 10)],
      );
      final p = checkWorld(mines(characters: const [foreman, slime, lost]));
      expect(
        p.where((x) => x.severity == Severity.error).map((x) => x.message),
        [
          '«Потерянный»: локация ссылается на несуществующий объект',
          '«Потерянный»: добыча ссылается на несуществующий объект',
        ],
      );
    });

    test('удалённый житель ломает квест, который он выдаёт и в шаге', () {
      expect(errors(mines(characters: const [slime])), [
        'broken_link', // выдающий
        'broken_link', // шаг 1: поговорить
      ]);
    });
  });

  group('проверка мира: предупреждения', () {
    test('в целом мире предупреждений нет', () {
      expect(checkWorld(mines()), isEmpty);
    });

    test('предмет, который не выпадает и не награда, нельзя получить', () {
      const noLoot = Character(
        id: 'char-slime',
        slug: 'sliz',
        title: 'Пепельный слизень',
        description: '',
        role: Role.enemy,
        locationId: 'loc-shaft',
        loot: [],
      );
      final w = mines(characters: const [foreman, noLoot]);
      expect(warnings(w, 'item_unobtainable'), [
        '«Ключ от лебёдки» нельзя получить: не выпадает и не выдаётся наградой',
      ]);
      // Кирка — награда квеста, её получить можно.
      expect(warnings(mines(), 'item_unobtainable'), isEmpty);
    });

    test('потолок урона: 4 + уровень × 2 × множитель редкости', () {
      expect(damageCeiling(2, Rarity.common), 8);
      expect(damageCeiling(1, Rarity.uncommon), closeTo(6.4, 1e-9));
      expect(damageCeiling(3, Rarity.rare), 13);
      expect(damageCeiling(5, Rarity.epic), closeTo(23, 1e-9));
      expect(damageCeiling(10, Rarity.legendary), closeTo(52, 1e-9));
    });

    test('урон 14 при потолке 8 — предупреждение; ровно 8 — нет', () {
      final w = withItems([
        weapon('item-14', title: 'Кайло', damage: 14),
        weapon('item-8', title: 'Лом', damage: 8),
      ]);
      expect(warnings(w, 'damage_over_ceiling'), [
        '«Кайло»: урон 14 выше потолка 8 (ур. 2, обычный)',
      ]);
    });

    test('эпический дешевле медианы редких; не дешевле — молчит', () {
      final w = withItems([
        weapon('r1', title: 'Р1', rarity: Rarity.rare, level: 5, price: 100),
        weapon('r2', title: 'Р2', rarity: Rarity.rare, level: 5, price: 60),
        // + Кирка: редкая за 40 → медиана 40, 60, 100 = 60
        weapon(
          'e1',
          title: 'Дешёвый',
          rarity: Rarity.epic,
          level: 5,
          price: 50,
        ),
        weapon(
          'e2',
          title: 'Честный',
          rarity: Rarity.epic,
          level: 5,
          price: 60,
        ),
      ]);
      expect(warnings(w, 'epic_cheaper_than_rare'), [
        '«Дешёвый»: эпический за 50 зол. дешевле медианы редких 60 зол.',
      ]);
    });

    test('медиана чётного числа редких — середина двух средних', () {
      final w = withItems([
        weapon('r1', title: 'Р1', rarity: Rarity.rare, level: 5, price: 100),
        // + Кирка за 40 → медиана 70
        weapon('e1', title: 'Эпик', rarity: Rarity.epic, level: 5, price: 69),
      ]);
      expect(warnings(w, 'epic_cheaper_than_rare'), [
        '«Эпик»: эпический за 69 зол. дешевле медианы редких 70 зол.',
      ]);
    });

    test('редких нет — эпический сравнивать не с чем', () {
      const cheapEpic = Item(
        id: 'e1',
        slug: 'e1',
        title: 'Эпик',
        kind: ItemKind.misc,
        rarity: Rarity.epic,
        level: 1,
        damage: null,
        defense: null,
        price: 1,
      );
      final w = WorldSnapshot(
        items: const [cheapEpic],
        characters: const [foreman],
        quests: [
          quest(steps: const [], rewardIds: const ['e1']),
        ],
      );
      expect(warnings(w, 'epic_cheaper_than_rare'), isEmpty);
    });

    test('повтор названий у объектов одного вида, без учёта регистра', () {
      final w = withItems([weapon('item-dup', title: ' кирка ')]);
      expect(warnings(w, 'duplicate_title'), [
        '«Кирка» — название повторяется у 2 предметов',
      ]);
      // Локация и предмет с одним названием — не повтор.
      final cross = WorldSnapshot(
        locations: const [shaft],
        items: [weapon('item-x', title: 'Штольня №3')],
      );
      expect(warnings(cross, 'duplicate_title'), isEmpty);
    });
  });

  test('правила — чистый Dart: без Flutter и без базы', () {
    for (final f in Directory('lib/check').listSync().whereType<File>()) {
      if (f.path.endsWith('check_screen.dart')) continue;
      final src = f.readAsStringSync();
      expect(src, isNot(contains('package:flutter')), reason: f.path);
      expect(src, isNot(contains('supabase')), reason: f.path);
      expect(src, isNot(contains('content_repo')), reason: f.path);
    }
  });
}
