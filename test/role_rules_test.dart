// Прибор ошибок ролей (22.11): квест выдаёт только житель, убить можно только врага,
// в событии стоят только враги — проверка мира ловит, если смена роли это ломает.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/quest.dart';

Character who(String id, Role role) => Character(
  id: id,
  slug: id,
  title: id,
  description: '',
  role: role,
  locationId: null,
  loot: const [],
);

List<String> rules(WorldSnapshot w) => [
  for (final p in checkWorld(w))
    if (p.severity == Severity.error) p.rule,
];

void main() {
  final quest = Quest(
    id: 'q',
    slug: 'q',
    title: 'Обвал',
    description: '',
    giverId: 'brigadir',
    rewardIds: const [],
    steps: const [
      QuestStep(kind: StepKind.kill, targetId: 'slizen', amount: 4),
    ],
  );
  const event = Event(
    id: 'e',
    slug: 'e',
    title: 'Засада',
    description: '',
    locationId: null,
    enemies: [EventEnemy(characterId: 'slizen', amount: 3)],
  );

  test('роли на своих местах — ошибок ролей нет', () {
    final w = WorldSnapshot(
      characters: [who('brigadir', Role.npc), who('slizen', Role.enemy)],
      quests: [quest],
    );
    expect(rules(w), isNot(contains(startsWith('quest_'))));
  });

  test('выдающий — враг; цель «убить» и враг события — житель', () {
    final w = WorldSnapshot(
      characters: [who('brigadir', Role.enemy), who('slizen', Role.npc)],
      quests: [quest],
      events: [event],
    );
    expect(
      rules(w),
      containsAll([
        'quest_giver_not_npc',
        'quest_kill_not_enemy',
        'event_enemy_not_enemy',
      ]),
    );
    final text = [for (final p in checkWorld(w)) p.message].join('\n');
    expect(text, contains('«Обвал»: квест выдаёт только житель'));
    expect(text, contains('убить можно только врага'));
    expect(text, contains('«Засада»: в событии стоят только враги'));
  });
}
