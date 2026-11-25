// Кто ссылается на объект: словами и с видом ссылки (значок в окне отказа).
// Непусто — удалять нельзя. Своя добыча врага, свои шаги квеста, свои враги и
// предметы события — не ссылки: уходят вместе с объектом.
import '../check/world_check.dart';
import 'event.dart';

/// Вид ссылки — по нему окно отказа ставит значок.
enum RefKind { nested, lives, drops, gives, step, reward, event }

/// Ссылка на объект: вид и слова («роняет: «Слизень»»).
typedef Ref = ({RefKind kind, String text});

/// События, на которых стоит объект [id]: его место, враг или предмет сцены.
List<Event> eventsOn(WorldSnapshot w, String id) => [
  for (final e in w.events)
    if (e.locationId == id ||
        e.enemies.any((x) => x.characterId == id) ||
        e.itemIds.contains(id))
      e,
];

/// Все ссылки на [id], события — последними.
List<Ref> refsTo(WorldSnapshot w, String id) => [
  ..._refsWithoutEvents(w, id),
  for (final e in w.events) ...[
    if (e.locationId == id)
      (kind: RefKind.event, text: 'здесь идёт событие «${e.title}»'),
    if (e.enemies.any((x) => x.characterId == id))
      (kind: RefKind.event, text: 'стоит в событии «${e.title}»'),
    if (e.itemIds.contains(id))
      (kind: RefKind.event, text: 'лежит в событии «${e.title}»'),
  ],
];

/// Кто ссылается на объект [id] — словами. Непусто — удалять нельзя.
List<String> referencesTo(WorldSnapshot w, String id) => [
  for (final r in refsTo(w, id)) r.text,
];

/// То же, но без событий: их ассистент объясняет отдельно (см. eventsOn).
List<String> referencesWithoutEvents(WorldSnapshot w, String id) => [
  for (final r in _refsWithoutEvents(w, id)) r.text,
];

List<Ref> _refsWithoutEvents(WorldSnapshot w, String id) => [
  for (final l in w.locations)
    if (l.parentId == id)
      (kind: RefKind.nested, text: 'вложено сюда: «${l.title}»'),
  for (final c in w.characters) ...[
    if (c.locationId == id)
      (kind: RefKind.lives, text: 'живёт здесь: «${c.title}»'),
    if (c.loot.any((l) => l.itemId == id))
      (kind: RefKind.drops, text: 'роняет: «${c.title}»'),
  ],
  for (final q in w.quests) ...[
    if (q.giverId == id)
      (kind: RefKind.gives, text: 'выдаёт квест «${q.title}»'),
    for (final (i, s) in q.steps.indexed)
      if (s.targetId == id)
        (kind: RefKind.step, text: 'шаг ${i + 1} квеста «${q.title}»'),
    if (q.rewardIds.contains(id))
      (kind: RefKind.reward, text: 'награда за квест «${q.title}»'),
  ],
];
