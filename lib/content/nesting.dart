// Вложенность мест (5а): Копи › Штольня №3 › Забой — не глубже трёх уровней.
// Чистый Dart над списком мест: им пользуются проверка, формы, страница места и область.
import 'character.dart';
import 'event.dart';
import 'location.dart';

/// Сколько уровней вложенности допустимо: место верхнего уровня — 1.
const maxNestingDepth = 3;

/// Места по id — для обхода вверх по родителям.
Map<String, Location> byId(List<Location> locations) => {
  for (final l in locations) l.id: l,
};

/// Предки места от ближайшего к верхнему. Цикл или битый родитель — обход обрывается.
List<Location> ancestorsOf(List<Location> locations, Location l) {
  final all = byId(locations);
  final out = <Location>[];
  final seen = {l.id};
  var p = l.parentId == null ? null : all[l.parentId];
  while (p != null && seen.add(p.id)) {
    out.add(p);
    p = p.parentId == null ? null : all[p.parentId];
  }
  return out;
}

/// Место лежит в цикле (само в себе — прямо или через других).
bool inCycle(List<Location> locations, Location l) {
  final all = byId(locations);
  final seen = <String>{};
  var p = l.parentId == null ? null : all[l.parentId];
  while (p != null) {
    if (p.id == l.id) return true;
    if (!seen.add(p.id)) return false;
    p = p.parentId == null ? null : all[p.parentId];
  }
  return false;
}

/// Уровень места: верхний — 1, вложенное в него — 2, …
int depthOf(List<Location> locations, Location l) =>
    ancestorsOf(locations, l).length + 1;

/// Прямые вложенные места.
List<Location> childrenOf(List<Location> locations, String id) => [
  for (final l in locations)
    if (l.parentId == id) l,
];

/// Все вложенные места на любой глубине (без самого места).
List<Location> descendantsOf(List<Location> locations, String id) {
  final out = <Location>[];
  final seen = {id};
  var frontier = [id];
  while (frontier.isNotEmpty) {
    final next = <String>[];
    for (final f in frontier) {
      for (final c in childrenOf(locations, f)) {
        if (seen.add(c.id)) {
          out.add(c);
          next.add(c.id);
        }
      }
    }
    frontier = next;
  }
  return out;
}

/// Сколько уровней занимает место вместе с вложенными: без вложенных — 1.
int heightOf(List<Location> locations, String id) {
  var h = 1;
  for (final c in childrenOf(locations, id)) {
    final ch = 1 + heightOf(locations, c.id);
    if (ch > h) h = ch;
  }
  return h;
}

/// Путь словами: «Копи › Штольня №3».
String pathOf(List<Location> locations, Location l) => [
  for (final a in ancestorsOf(locations, l).reversed) a.title,
  l.title,
].join(' › ');

/// Куда можно положить место [self] (null — новое место): не в себя и не во вложенные,
/// и так, чтобы вместе со своими вложенными оно не ушло глубже [maxNestingDepth].
List<Location> allowedParents(List<Location> locations, Location? self) {
  final height = self == null ? 1 : heightOf(locations, self.id);
  final banned = self == null
      ? const <String>{}
      : {self.id, for (final d in descendantsOf(locations, self.id)) d.id};
  return [
    for (final l in locations)
      if (!banned.contains(l.id) &&
          depthOf(locations, l) + height <= maxNestingDepth)
        l,
  ];
}

/// Место и все вложенные в него на любой глубине — id.
Set<String> placeAndInside(List<Location> locations, String id) => {
  id,
  for (final d in descendantsOf(locations, id)) d.id,
};

/// Жители места по всей глубине: «Кто здесь» на странице места и число на блоке карты —
/// одно правило (ревью 5а.3).
List<Character> residentsOf(
  List<Location> locations,
  List<Character> characters,
  String id,
) {
  final places = placeAndInside(locations, id);
  return [
    for (final ch in characters)
      if (places.contains(ch.locationId)) ch,
  ];
}

/// События места по всей глубине: раздел «События» на странице места и ⚡ на блоке карты —
/// одно правило, как у жителей.
List<Event> eventsIn(List<Location> locations, List<Event> events, String id) {
  final places = placeAndInside(locations, id);
  return [
    for (final e in events)
      if (places.contains(e.locationId)) e,
  ];
}
