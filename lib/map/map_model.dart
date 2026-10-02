// Карта-холст (5а): что показывает блок места и где он стоит. Чистый Dart над снимком мира.
import 'dart:ui';

import '../check/world_check.dart';
import '../content/content_repo.dart' show Spot;
import '../content/location.dart';
import '../content/nesting.dart';

/// Размер блока места на холсте (dp при масштабе 1).
const blockSize = Size(152, 108);

/// Зазор между блоками автораскладки.
const blockGap = 20.0;

/// Столбцов в автораскладке — два блока в ширину телефона. Постоянное число: новое место
/// не перестраивает сетку и не двигает старые.
const gridColumns = 2;

/// Что видно на блоке места.
typedef PlaceStats = ({
  int residents,
  int inner,
  int problems,
  Severity? worst,
});

/// Жители — по всей глубине, тем же правилом, что «Кто здесь» на странице места (residentsOf);
/// вложенные — прямые;
/// проблемы — у самого места, вложенных мест и всех их жителей.
PlaceStats placeStats(WorldSnapshot w, Location l, List<Problem> problems) {
  final places = placeAndInside(w.locations, l.id);
  final residents = {
    for (final ch in residentsOf(w.locations, w.characters, l.id)) ch.id,
  };
  final mine = [
    for (final p in problems)
      if (places.contains(p.objectId) || residents.contains(p.objectId)) p,
  ];
  return (
    residents: residents.length,
    inner: childrenOf(w.locations, l.id).length,
    problems: mine.length,
    worst: mine.isEmpty
        ? null
        : mine.any((p) => p.severity == Severity.error)
        ? Severity.error
        : Severity.warning,
  );
}

/// Места одного уровня холста: [parentId] null — верхний уровень.
List<Location> levelOf(List<Location> locations, String? parentId) => [
  for (final l in locations)
    if (l.parentId == parentId) l,
];

/// Где стоит каждый блок уровня: перетащенный автором — где положили; остальные — в первые
/// свободные клетки сетки по порядку. Новое место встаёт в свободную клетку и не двигает
/// старые (5а.4). Положение без записи в базу — пока автор сам не перетащит блок.
Map<String, Offset> placeLevel(List<Location> level, Map<String, Spot> saved) {
  final out = <String, Offset>{
    for (final l in level)
      if (saved[l.id] case final s?) l.id: Offset(s.x, s.y),
  };
  // Клетка занята, если её блок с половиной зазора вокруг задевает уже стоящий.
  bool free(Offset o) => out.values.every(
    (p) => !(o & blockSize).inflate(blockGap / 2 - 1).overlaps(p & blockSize),
  );
  var cell = 0;
  for (final l in level) {
    if (out.containsKey(l.id)) continue;
    late Offset o;
    do {
      o = Offset(
        (cell % gridColumns) * (blockSize.width + blockGap),
        (cell ~/ gridColumns) * (blockSize.height + blockGap),
      );
      cell++;
    } while (!free(o));
    out[l.id] = o;
  }
  return out;
}
