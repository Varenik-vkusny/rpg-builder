// Правила проверки мира на снимке в памяти — без экрана и без базы.
// База ошибок не пускает, поэтому каждое правило-ошибку доказывает только этот тест.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
