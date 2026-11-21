// Прибор «жетоны места — по времени создания» без базы (владелец 19.11, найдено 21.11):
// вперемешку для жителей, врагов и событий; без времени (копия плана) — в конце;
// правка жестом и планом время не теряет — иначе в тесном месте старый жетон
// уезжал бы в хвост, пока на холсте план. Настоящая база — object_order_db_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/map/gesture_move.dart';
import 'package:rpg_builder/map/holst_scene.dart';

DateTime t(int m) => DateTime.utc(2026, 11, 21, 10, m);

Character npc(String id, int? m, {String place = 'kopi'}) => Character(
  id: id,
  slug: id,
  title: id,
  description: '',
  role: Role.npc,
  locationId: place,
  loot: const [],
  createdAt: m == null ? null : t(m),
);

void main() {
  const kopi = Location(
    id: 'kopi',
    slug: 'kopi',
    title: 'Копи',
    description: '',
    levelMin: 1,
    levelMax: 5,
  );
  const zaboy = Location(
    id: 'zaboy',
    slug: 'zaboy',
    title: 'Забой',
    description: '',
    levelMin: 1,
    levelMax: 5,
  );
  final ambush = Event(
    id: 'zasada',
    slug: 'zasada',
    title: 'zasada',
    description: '',
    locationId: 'kopi',
    createdAt: t(2),
  );
  final w = WorldSnapshot(
    locations: const [kopi, zaboy],
    characters: [npc('brigadir', 1), npc('goblin', 3), npc('novyi', null)],
    events: [ambush],
  );
  List<String> order(WorldSnapshot w) => [
    for (final tok in buildScene(w, null).places.first.tokens) tok.id,
  ];

  test('по времени вперемешку, без времени — в конце', () {
    expect(order(w), ['brigadir', 'zasada', 'goblin', 'novyi']);
  });

  test('жест «перенести» и правка планом время не теряют', () {
    final moved = moveObject('w', w, 'zasada', 'zaboy').applyTo(w);
    expect(moved.events.single.createdAt, t(2));
    final plan = Plan.fromJson({
      'summary': '',
      'ops': [
        {
          'action': 'update',
          'type': 'character',
          'slug': 'brigadir',
          'fields': {'level': 3},
        },
        {
          'action': 'update',
          'type': 'event',
          'slug': 'zasada',
          'fields': {'description': 'в пыли'},
        },
      ],
    });
    final (copy, ops) = applyToCopy(w, plan);
    expect([for (final r in ops) r.error], [null, null]);
    expect(copy.characters.first.createdAt, t(1));
    expect(copy.events.single.createdAt, t(2));
    expect(order(copy), ['brigadir', 'zasada', 'goblin', 'novyi']);
  });

  test('созданное одним планом — по названию, как отдаст база', () {
    expect(['Яма', 'Ёж', 'Еда', 'акула', 'Бес']..sort(titleOrder), [
      'акула',
      'Бес',
      'Еда',
      'Ёж',
      'Яма',
    ]);
    final plan = Plan.fromJson({
      'summary': '',
      'ops': [
        for (final (slug, title) in [
          ('vepr', 'Вепрь'),
          ('akula', 'Акула'),
          ('bes', 'Бес'),
        ])
          {
            'action': 'create',
            'type': 'character',
            'slug': slug,
            'fields': {'title': title, 'role': 'enemy', 'location': 'kopi'},
          },
      ],
    });
    final (copy, ops) = applyToCopy(w, plan);
    expect([for (final r in ops) r.error], [null, null, null]);
    expect(order(copy), [
      'brigadir',
      'zasada',
      'goblin',
      'novyi',
      'new-character-akula',
      'new-character-bes',
      'new-character-vepr',
    ]);
  });
}
