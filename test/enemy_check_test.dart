// Предупреждения про врага (срез 2.7): атака выше потолка уровня,
// уровень выше своей локации. Чистый Dart над снимком мира.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/warning_rules.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/location.dart';

const shaft = Location(
  id: 'loc-shaft',
  slug: 'shtolnya_3',
  title: 'Штольня №3',
  description: '',
  levelMin: 2,
  levelMax: 4,
);

Character enemy({
  String id = 'char-enemy',
  String title = 'Утопленник',
  Role role = Role.enemy,
  int level = 3,
  int attack = 5,
  String? locationId = 'loc-shaft',
}) => Character(
  id: id,
  slug: id,
  title: title,
  description: '',
  role: role,
  locationId: locationId,
  loot: const [],
  level: level,
  hp: 30,
  attack: attack,
);

List<String> warnings(List<Character> cs, String rule) => [
  for (final p in checkWorld(
    WorldSnapshot(locations: const [shaft], characters: cs),
  ))
    if (p.severity == Severity.warning && p.rule == rule) p.message,
];

void main() {
  group('враг: атака и уровень', () {
    test('потолок атаки: 4 + уровень × 2', () {
      expect(attackCeiling(1), 6);
      expect(attackCeiling(2), 8);
      expect(attackCeiling(3), 10);
    });

    test('атака 14 у врага 3 уровня выше потолка 10; ровно 10 — нет', () {
      final w = [
        enemy(title: 'Утопленник', attack: 14),
        enemy(id: 'char-2', title: 'Крепильщик', attack: 10),
      ];
      expect(warnings(w, 'attack_over_ceiling'), [
        '«Утопленник»: атака 14 выше потолка 10 (ур. 3)',
      ]);
    });

    test('атака жителя выше потолка — не предупреждение', () {
      final w = [enemy(role: Role.npc, attack: 40)];
      expect(warnings(w, 'attack_over_ceiling'), isEmpty);
    });

    test('враг 5 уровня в локации 2–4 — предупреждение; 4 уровня — нет', () {
      final w = [
        enemy(title: 'Босс', level: 5),
        enemy(id: 'char-2', title: 'Слизень', level: 4),
      ];
      expect(warnings(w, 'enemy_over_location'), [
        '«Босс»: ур. 5 выше уровней локации «Штольня №3» (2–4)',
      ]);
    });

    test('без локации и житель выше локации — не предупреждение', () {
      final w = [
        enemy(level: 9, locationId: null),
        enemy(id: 'char-2', role: Role.npc, level: 9),
      ];
      expect(warnings(w, 'enemy_over_location'), isEmpty);
    });
  });
}
