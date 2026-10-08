// Правила проверки про события (5б.1): событие без места и битые ссылки — ошибки;
// враг сильнее места сцены — предупреждение; предмет из события — получаемый;
// место, враг и предмет, на которых стоит событие, не удаляются.
// Чистый Dart над снимком мира: база таких ошибок не пускает, доказывает только этот тест.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/event_edit.dart';
import 'package:rpg_builder/content/manual_edit.dart';

import 'world_check_test.dart' show foreman, key, mines, pick, shaft, slime;

Event ambush({
  String? locationId = 'loc-shaft',
  List<EventEnemy> enemies = const [
    EventEnemy(id: 'ee-1', characterId: 'char-slime', amount: 3),
  ],
  List<EventItem> items = const [EventItem(id: 'ei-1', itemId: 'item-key')],
}) => Event(
  id: 'event-ambush',
  slug: 'zasada_u_lebyodki',
  title: 'Засада у лебёдки',
  description: '',
  locationId: locationId,
  enemies: enemies,
  items: items,
);

WorldSnapshot withEvents(List<Event> events, {List<Character>? characters}) {
  final w = mines(characters: characters ?? const [foreman, slime]);
  return WorldSnapshot(
    locations: w.locations,
    items: w.items,
    characters: w.characters,
    quests: w.quests,
    events: events,
  );
}

/// Слизень из приёмки с другим уровнем, местом и добычей.
Character slimeWith({
  int level = 1,
  String? locationId = 'loc-shaft',
  List<LootDrop> loot = const [LootDrop(itemId: 'item-key', chance: 35)],
}) => Character(
  id: 'char-slime',
  slug: 'sliz',
  title: 'Пепельный слизень',
  description: '',
  role: Role.enemy,
  locationId: locationId,
  loot: loot,
  level: level,
);

List<String> found(WorldSnapshot w) => [
  for (final p in checkWorld(w)) '${p.severity.name} ${p.rule}@${p.objectId}',
];

void main() {
  group('проверка мира: события', () {
    test('целое событие проблем не даёт', () {
      expect(checkWorld(withEvents([ambush()])), isEmpty);
    });

    test('событие без места — ошибка', () {
      expect(found(withEvents([ambush(locationId: null)])), [
        'error event_no_location@event-ambush',
      ]);
    });

    test('битые ссылки события — ошибки: место, враг, предмет', () {
      final w = withEvents([
        ambush(
          locationId: 'loc-gone',
          enemies: const [EventEnemy(characterId: 'char-gone', amount: 1)],
          items: const [EventItem(itemId: 'item-gone')],
        ),
      ]);
      expect(
        [
          for (final p in checkWorld(w))
            if (p.severity == Severity.error) p.message,
        ],
        [
          '«Засада у лебёдки»: место ссылается на несуществующий объект',
          '«Засада у лебёдки»: враг ссылается на несуществующий объект',
          '«Засада у лебёдки»: предмет ссылается на несуществующий объект',
        ],
      );
    });

    test('враг сильнее места сцены — предупреждение на событии', () {
      // Слизень 5-го уровня нигде не живёт, а стоит в сцене в штольне 2–4.
      final w = withEvents(
        [ambush()],
        characters: [foreman, slimeWith(level: 5, locationId: null)],
      );
      expect(found(w), ['warning event_enemy_over_location@event-ambush']);
      expect(
        checkWorld(w).single.message,
        '«Засада у лебёдки»: «Пепельный слизень» ур. 5 выше уровней места '
        '«Штольня №3» (2–4)',
      );
    });

    test('враг на верхнем уровне места — предупреждения нет', () {
      final w = withEvents(
        [ambush()],
        characters: [foreman, slimeWith(level: 4, locationId: null)],
      );
      expect(checkWorld(w), isEmpty);
    });

    test('предмет из события считается получаемым', () {
      // Ключ ни с кого не падает и не награда: без события — «нельзя получить».
      final cs = [foreman, slimeWith(loot: const [])];
      expect(found(withEvents(const [], characters: cs)), [
        'warning item_unobtainable@item-key',
      ]);
      expect(checkWorld(withEvents([ambush()], characters: cs)), isEmpty);
    });

    test('повтор названия у двух событий — предупреждение', () {
      final w = withEvents([
        ambush(),
        const Event(
          id: 'event-2',
          slug: 'zasada_2',
          title: 'засада у лебёдки ',
          description: '',
          locationId: 'loc-shaft',
        ),
      ]);
      expect(
        [for (final p in checkWorld(w)) p.message],
        ['«Засада у лебёдки» — название повторяется у 2 событий'],
      );
    });
  });

  group('событие держит ссылки', () {
    final w = withEvents([ambush()]);

    test('место, врага и предмет события удалить нельзя', () {
      expect(
        referencesTo(w, shaft.id),
        contains('здесь идёт событие «Засада у лебёдки»'),
      );
      expect(
        referencesTo(w, slime.id),
        contains('стоит в событии «Засада у лебёдки»'),
      );
      expect(
        referencesTo(w, key.id),
        contains('лежит в событии «Засада у лебёдки»'),
      );
      expect(referencesTo(w, pick.id), [
        'награда за квест «Обвал в третьей штольне»',
      ]);
    });

    test(
      'само событие удаляется: его враги и предметы — не ссылки на него',
      () {
        expect(referencesTo(w, 'event-ambush'), isEmpty);
        final after = deleteObject(
          'w',
          type: 'event',
          id: 'event-ambush',
          slug: 'zasada_u_lebyodki',
          title: 'Засада у лебёдки',
        ).applyTo(w);
        expect(after.events, isEmpty);
        expect(after.quests, hasLength(1));
      },
    );

    test('план ассистента не теряет события и не удаляет предмет события', () {
      final (copy, results) = applyToCopy(
        w,
        const Plan(
          summary: 'убрать ключ',
          ops: [
            PlanOp(action: OpAction.delete, type: OpType.item, slug: 'klyuch'),
          ],
        ),
      );
      expect(copy.events.single.title, 'Засада у лебёдки');
      expect(
        results.single.error,
        // Формулировка ошибки копии сменена решением владельца 08.10 (5б.4, Ступень 1).
        contains('на «Ключ от лебёдки» стоит событие «Засада у лебёдки»'),
      );
      expect(copy.items.map((i) => i.slug), contains('klyuch'));
    });
  });

  group('правка события вручную', () {
    final old = ambush();
    const slugs = {
      'char-slime': 'sliz',
      'item-key': 'klyuch',
      'item-pick': 'kirka',
    };
    NewEvent draft({
      String title = 'Засада у лебёдки',
      List<EventEnemy> enemies = const [
        EventEnemy(characterId: 'char-slime', amount: 3),
      ],
      List<String> itemIds = const ['item-key'],
    }) => NewEvent(
      title: title,
      description: '',
      locationId: 'loc-shaft',
      enemies: enemies,
      itemIds: itemIds,
    );

    test('ничего не поменяли — операций нет', () {
      expect(editEvent('w', old, draft(), slugs).isEmpty, isTrue);
    });

    test('число врагов, предметы и название — операциями по разнице', () {
      final e = editEvent(
        'w',
        old,
        draft(
          title: 'Засада',
          enemies: const [EventEnemy(characterId: 'char-slime', amount: 5)],
          itemIds: const ['item-pick'],
        ),
        slugs,
      );
      expect(
        [
          for (final op in e.ops)
            '${op['action']} ${op['type']} ${op['label']} ${op['row']}',
        ],
        [
          'update event zasada_u_lebyodki '
              '{id: event-ambush, project_id: w, title: Засада}',
          'update event_enemy zasada_u_lebyodki/sliz '
              '{id: ee-1, project_id: w, amount: 5}',
          'delete event_item zasada_u_lebyodki/klyuch '
              '{id: ei-1, project_id: w}',
          'create event_item zasada_u_lebyodki/kirka '
              '{project_id: w, event_id: event-ambush, item_id: item-pick}',
        ],
      );
      final after = e.applyTo(withEvents([old])).events.single;
      expect(after.title, 'Засада');
      expect(after.enemies.single.amount, 5);
      expect(after.enemies.single.id, 'ee-1');
      expect(after.itemIds, ['item-pick']);
    });

    test('убрали врага — строка удаляется по своему id', () {
      final e = editEvent('w', old, draft(enemies: const []), slugs);
      expect(e.ops.single['action'], 'delete');
      expect(e.ops.single['type'], 'event_enemy');
      expect(e.ops.single['row'], {'id': 'ee-1', 'project_id': 'w'});
    });
  });
}
