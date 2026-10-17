// Холст мира (5е): что стоит на холсте одного уровня и где. Чистый Dart над снимком мира.
// Место — плашка с цветной шапкой; внутри жетоны (жители, враги, события) и двери вложенных
// мест. Предметы, квесты и персонажи без места — на полке у нижнего края.
import 'dart:math' as math;
import 'dart:ui';

import '../check/world_check.dart';
import '../content/character.dart';
import '../content/location.dart';
import '../content/nesting.dart';
import 'map_model.dart' show levelOf;

/// Жетон объекта: 148 × 48 (решение владельца 16.10).
const tokenSize = Size(148, 48);
const cellGap = 8.0;

/// Высота шапки места с отступом до первого ряда жетонов.
const placeHead = 36.0;

/// Ширина места: узкое — один столбец жетонов, широкое — два. Два узких = одно широкое.
const narrowWidth = 164.0, wideWidth = 344.0, placeGap = 16.0;

/// Больше рядов место не растёт: остальное — «ещё N», не спрятано молча.
const maxRows = 5;

enum TokenKind { enemy, npc, event, item, quest }

/// Объект на холсте или на полке. [count] — «×3» на значке, null — без числа.
class HolstToken {
  const HolstToken({
    required this.id,
    required this.slug,
    required this.kind,
    required this.title,
    this.count,
    this.placeId,
    this.sub,
    this.rect = Rect.zero,
  });

  final String id;
  final String slug;
  final TokenKind kind;
  final String title;
  final int? count;
  final String? placeId;

  /// Вид предмета (ItemKind.name) — по нему значок; у остальных null.
  final String? sub;

  /// Где стоит в координатах холста (у полки — пусто: полку раскладывает экран).
  final Rect rect;
}

/// Дверь — вложенное место внутри места: высотой в два жетона.
class HolstDoor {
  const HolstDoor(this.place, this.rect, this.inside);

  final Location place;
  final Rect rect;

  /// Кто внутри — именами (жители, враги, события), для строки на двери.
  final List<String> inside;
}

class HolstPlace {
  const HolstPlace({
    required this.place,
    required this.rect,
    required this.tokens,
    required this.doors,
    required this.overflow,
    required this.overflowRect,
  });

  final Location place;
  final Rect rect;
  final List<HolstToken> tokens;
  final List<HolstDoor> doors;

  /// Сколько жетонов не влезло; [overflowRect] — клетка «ещё N».
  final int overflow;
  final Rect? overflowRect;

  /// Все жетоны места, включая не влезшие, — для чисел «издалека».
  int get total => tokens.length + overflow;
}

/// Холст одного уровня.
class HolstScene {
  const HolstScene({
    required this.places,
    required this.shelf,
    required this.bounds,
    required this.all,
  });

  final List<HolstPlace> places;
  final List<HolstToken> shelf;
  final Rect bounds;

  /// Все объекты мира по id — имена в строке связей, даже если объект на другом уровне.
  final Map<String, HolstToken> all;

  Iterable<HolstToken> get onCanvas => places.expand((p) => p.tokens);
}

TokenKind kindOf(Role r) => r == Role.enemy ? TokenKind.enemy : TokenKind.npc;

/// Все объекты мира жетонами (без положения). Число на враге — сколько его в сценах
/// своего места («враги ×3» в событиях там же); нет сцен — числа нет.
Map<String, HolstToken> worldTokens(WorldSnapshot w) {
  int? countOf(Character c) {
    var n = 0;
    for (final e in w.events) {
      if (e.locationId != c.locationId) continue;
      for (final x in e.enemies) {
        if (x.characterId == c.id) n += x.amount;
      }
    }
    return n > 0 ? n : null;
  }

  return {
    for (final c in w.characters)
      c.id: HolstToken(
        id: c.id,
        slug: c.slug,
        kind: kindOf(c.role),
        title: c.title,
        count: c.role == Role.enemy ? countOf(c) : null,
        placeId: c.locationId,
      ),
    for (final e in w.events)
      e.id: HolstToken(
        id: e.id,
        slug: e.slug,
        kind: TokenKind.event,
        title: e.title,
        placeId: e.locationId,
      ),
    for (final i in w.items)
      i.id: HolstToken(
        id: i.id,
        slug: i.slug,
        kind: TokenKind.item,
        title: i.title,
        sub: i.kind.name,
      ),
    for (final q in w.quests)
      q.id: HolstToken(
        id: q.id,
        slug: q.slug,
        kind: TokenKind.quest,
        title: q.title,
      ),
  };
}

HolstToken _at(HolstToken t, Rect r) => HolstToken(
  id: t.id,
  slug: t.slug,
  kind: t.kind,
  title: t.title,
  count: t.count,
  placeId: t.placeId,
  sub: t.sub,
  rect: r,
);

/// Клетка [col], [row] места с левым верхним углом [o].
Rect _cell(Offset o, int col, int row, {int rows = 1}) => Rect.fromLTWH(
  o.dx + cellGap + col * (tokenSize.width + cellGap),
  o.dy + placeHead + row * (tokenSize.height + cellGap),
  tokenSize.width,
  rows * tokenSize.height + (rows - 1) * cellGap,
);

/// Широкое место — если есть двери или жетонов больше трёх.
bool isWide(int tokens, int doors) => doors > 0 || tokens > 3;

/// Раскладка одного места в точке [o]: двери — в правом столбце сверху, жетоны — в
/// свободные клетки по рядам. Не влезло в [maxRows] — последняя клетка «ещё N».
HolstPlace layPlace(
  Location place,
  Offset o,
  List<HolstToken> tokens,
  List<HolstDoor Function(Rect)> doors,
) {
  final wide = isWide(tokens.length, doors.length);
  final cols = wide ? 2 : 1;
  final doorRows = 2 * doors.length;
  int freeCells(int rows) => rows * cols - doorRows;
  var rows = math.max(1, doorRows);
  while (freeCells(rows) < tokens.length &&
      rows < math.max(maxRows, doorRows)) {
    rows++;
  }
  final cells = <Rect>[
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < cols; c++)
        if (!(wide && c == 1 && r < doorRows)) _cell(o, c, r),
  ];
  final fits = tokens.length <= cells.length;
  final shown = fits ? tokens.length : cells.length - 1;
  final width = wide ? wideWidth : narrowWidth;
  return HolstPlace(
    place: place,
    rect: Rect.fromLTWH(
      o.dx,
      o.dy,
      width,
      placeHead + rows * (tokenSize.height + cellGap) + cellGap,
    ),
    tokens: [for (var i = 0; i < shown; i++) _at(tokens[i], cells[i])],
    doors: [for (final (i, d) in doors.indexed) d(_cell(o, 1, 2 * i, rows: 2))],
    overflow: tokens.length - shown,
    overflowRect: fits ? null : cells.last,
  );
}

/// Холст уровня: [focus] null — места верхнего уровня; иначе — само место, в которое
/// вошли через дверь, с его жителями и дверями глубже. Места идут рядами: широкое — одно в ряд,
/// узкие — по два. Порядок — как в мире: новое место встаёт в конец и не двигает старые.
HolstScene buildScene(WorldSnapshot w, Location? focus) {
  final all = worldTokens(w);
  final level = focus == null ? levelOf(w.locations, null) : [focus];
  List<HolstToken> inPlace(String id) => [
    for (final t in all.values)
      if (t.placeId == id &&
          (t.kind == TokenKind.npc ||
              t.kind == TokenKind.enemy ||
              t.kind == TokenKind.event))
        t,
  ];
  HolstDoor Function(Rect) door(Location d) =>
      (r) => HolstDoor(d, r, [for (final t in inPlace(d.id)) t.title]);

  final places = <HolstPlace>[];
  var y = 0.0, x = 0.0, rowH = 0.0;
  for (final l in level) {
    final tokens = inPlace(l.id);
    final doors = [for (final c in childrenOf(w.locations, l.id)) door(c)];
    final wide = isWide(tokens.length, doors.length);
    // Широкое или второе узкое не влезает в ряд — новый ряд.
    if (x > 0 && (wide || x + narrowWidth > wideWidth)) {
      y += rowH + placeGap;
      x = 0;
      rowH = 0;
    }
    final p = layPlace(l, Offset(x, y), tokens, doors);
    places.add(p);
    rowH = math.max(rowH, p.rect.height);
    x += p.rect.width + placeGap;
  }
  var bounds = Rect.zero;
  for (final p in places) {
    bounds = bounds.expandToInclude(p.rect);
  }
  final placed = {for (final l in w.locations) l.id};
  return HolstScene(
    places: places,
    shelf: [
      for (final t in all.values)
        if (t.kind == TokenKind.quest) t,
      for (final t in all.values)
        if (t.kind == TokenKind.item) t,
      // Персонаж без места не прячется: он на полке.
      for (final t in all.values)
        if ((t.kind == TokenKind.npc || t.kind == TokenKind.enemy) &&
            !placed.contains(t.placeId))
          t,
    ],
    bounds: bounds,
    all: all,
  );
}

/// Числа места «издалека»: жители, враги (со счётом), события, вложенные.
typedef FarStats = ({int residents, int enemies, int events, int inner});

FarStats farStats(WorldSnapshot w, HolstPlace p) {
  final all = worldTokens(w);
  final mine = [
    for (final t in all.values)
      if (t.placeId == p.place.id) t,
  ];
  return (
    residents: mine.where((t) => t.kind == TokenKind.npc).length,
    enemies: mine
        .where((t) => t.kind == TokenKind.enemy)
        .fold(0, (s, t) => s + (t.count ?? 1)),
    events: mine.where((t) => t.kind == TokenKind.event).length,
    inner: p.doors.length,
  );
}
