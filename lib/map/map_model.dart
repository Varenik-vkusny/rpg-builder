// Карта-холст (5а): что показывает блок места и где он стоит. Чистый Dart над снимком мира.
import 'dart:math' as math;
import 'dart:ui';

import '../check/world_check.dart';
import '../content/location.dart';
import '../content/nesting.dart';

/// Размер блока места на холсте (dp при масштабе 1).
const blockSize = Size(152, 108);

/// Зазор между блоками автораскладки.
const blockGap = 20.0;

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

/// Места без сохранённого положения встают сеткой, почти квадратом: n мест — √n столбцов.
List<Offset> autoLayout(int n) {
  final cols = math.max(1, math.sqrt(n).ceil());
  return [
    for (var i = 0; i < n; i++)
      Offset(
        (i % cols) * (blockSize.width + blockGap),
        (i ~/ cols) * (blockSize.height + blockGap),
      ),
  ];
}
