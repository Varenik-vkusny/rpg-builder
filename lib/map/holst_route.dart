// Холст мира (5е): прокладка нити в обход блоков (находка владельца на телефоне 17.10:
// нить шла сквозь Бригадира, и казалось, что «убить ×3» — про него). Нить идёт по
// свободным проходам под прямым углом: сетка с шагом 8, поиск кратчайшего пути, за
// каждый поворот — штраф, чтобы углов было мало. Чистый Dart, координаты экрана холста.
import 'dart:math' as math;
import 'dart:ui';

const _step = 8.0;

/// Штраф за поворот — в шагах сетки: прямая на 3 клетки длиннее лучше лишнего угла.
const _turn = 3;

/// Штраф за клетку, по которой уже идёт другая нить: у каждой нити — своя полоса,
/// иначе нити сливаются в общий ствол и не понять, чья подпись.
const _shared = 6;

/// Путь от блока [a] к блоку [b] в обход [blocks] (сами [a] и [b] не мешают).
/// [onlyTop] — блоки, к которым подходят только сверху (полка). Пути нет — null.
List<Offset>? routeAround(
  Rect a,
  Rect b,
  List<Rect> blocks,
  Size area, {
  bool aOnlyTop = false,
  bool bOnlyTop = false,
  Rect? forbidden,
  Set<Offset> taken = const {},
}) {
  final cols = (area.width / _step).ceil() + 1;
  final rows = (area.height / _step).ceil() + 1;
  if (cols <= 0 || rows <= 0) return null;
  final wall = List<bool>.filled(cols * rows, false);
  void mark(Rect r) {
    final c0 = math.max(0, (r.left / _step).floor());
    final c1 = math.min(cols - 1, (r.right / _step).ceil());
    final r0 = math.max(0, (r.top / _step).floor());
    final r1 = math.min(rows - 1, (r.bottom / _step).ceil());
    for (var y = r0; y <= r1; y++) {
      for (var x = c0; x <= c1; x++) {
        wall[y * cols + x] = true;
      }
    }
  }

  for (final r in blocks) {
    if (r == a || r == b) continue;
    mark(r.inflate(4));
  }
  if (forbidden != null) mark(forbidden);
  mark(a);
  mark(b);

  /// Выходы из блока: середины сторон, на шаг снаружи.
  List<(int, int)> ports(Rect r, bool onlyTop) => [
    ((r.center.dx / _step).round(), ((r.top - _step) / _step).floor()),
    if (!onlyTop) ...[
      ((r.center.dx / _step).round(), ((r.bottom + _step) / _step).ceil()),
      (((r.left - _step) / _step).floor(), (r.center.dy / _step).round()),
      (((r.right + _step) / _step).ceil(), (r.center.dy / _step).round()),
    ],
  ];
  bool inside(int x, int y) => x >= 0 && y >= 0 && x < cols && y < rows;

  final starts = [
    for (final (x, y) in ports(a, aOnlyTop))
      if (inside(x, y)) (x, y),
  ];
  final goals = {
    for (final (x, y) in ports(b, bOnlyTop))
      if (inside(x, y)) y * cols + x,
  };
  if (starts.isEmpty || goals.isEmpty) return null;
  for (final (x, y) in starts) {
    wall[y * cols + x] = false;
  }
  for (final g in goals) {
    wall[g] = false;
  }

  // Состояние — клетка и направление (0 →, 1 ↓, 2 ←, 3 ↑, 4 — ещё не шли).
  const dx = [1, 0, -1, 0], dy = [0, 1, 0, -1];
  final n = cols * rows * 5;
  final cost = List<int>.filled(n, 1 << 30);
  final from = List<int>.filled(n, -1);
  final queue = _Heap();
  int h(int cell) {
    final x = cell % cols, y = cell ~/ cols;
    var best = 1 << 30;
    for (final g in goals) {
      final d = (g % cols - x).abs() + (g ~/ cols - y).abs();
      if (d < best) best = d;
    }
    return best;
  }

  for (final (x, y) in starts) {
    final s = (y * cols + x) * 5 + 4;
    cost[s] = 0;
    queue.push(h(y * cols + x), s);
  }
  var end = -1, guard = 0;
  // Предел — по размеру сетки: на любом экране поиск успевает обойти её целиком.
  while (queue.isNotEmpty && guard++ < n * 4) {
    final (f, s) = queue.pop();
    // Устаревшая запись: до этой клетки уже нашли путь короче.
    if (f - h(s ~/ 5) > cost[s]) continue;
    final cell = s ~/ 5, dir = s % 5;
    if (goals.contains(cell)) {
      end = s;
      break;
    }
    final x = cell % cols, y = cell ~/ cols;
    for (var d = 0; d < 4; d++) {
      if (dir != 4 && (d + 2) % 4 == dir) continue;
      final nx = x + dx[d], ny = y + dy[d];
      if (!inside(nx, ny) || wall[ny * cols + nx]) continue;
      final ns = (ny * cols + nx) * 5 + d;
      final busy = taken.contains(Offset(nx * _step, ny * _step));
      final c =
          cost[s] +
          1 +
          (dir != 4 && d != dir ? _turn : 0) +
          (busy ? _shared : 0);
      if (c < cost[ns]) {
        cost[ns] = c;
        from[ns] = s;
        queue.push(c + h(ns ~/ 5), ns);
      }
    }
  }
  if (end < 0) return null;

  // Клетки пути → углы; концы — на гранях блоков.
  final cells = <int>[];
  for (var s = end; s >= 0; s = from[s]) {
    cells.add(s ~/ 5);
  }
  final pts = [
    for (final c in cells.reversed)
      Offset((c % cols) * _step, (c ~/ cols) * _step),
  ];
  final first = _edge(a, pts.first), last = _edge(b, pts.last);
  return _corners([first, ...pts, last]);
}

/// Точка на грани [r], ближайшая к выходу [p] (выход — на шаг снаружи стороны).
Offset _edge(Rect r, Offset p) {
  if (p.dy <= r.top) return Offset(p.dx, r.top);
  if (p.dy >= r.bottom) return Offset(p.dx, r.bottom);
  if (p.dx <= r.left) return Offset(r.left, p.dy);
  return Offset(r.right, p.dy);
}

/// Только углы ломаной: точки на одной прямой выкидываются.
List<Offset> _corners(List<Offset> pts) {
  final out = <Offset>[pts.first];
  for (var i = 1; i < pts.length - 1; i++) {
    final a = out.last, b = pts[i], c = pts[i + 1];
    final straight =
        (a.dx == b.dx && b.dx == c.dx) || (a.dy == b.dy && b.dy == c.dy);
    if (!straight) out.add(b);
  }
  out.add(pts.last);
  return out;
}

/// Точки сетки, по которым идёт путь, — их займёт следующая нить.
Iterable<Offset> pathCells(List<Offset> pts) sync* {
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final n = ((b - a).distance / _step).ceil();
    for (var k = 0; k <= n; k++) {
      final p = Offset.lerp(a, b, n == 0 ? 0 : k / n)!;
      yield Offset(
        (p.dx / _step).round() * _step,
        (p.dy / _step).round() * _step,
      );
    }
  }
}

/// Отрезок [s] лежит на чужой нити (идёт по ней хотя бы частью) — подпись туда не ставить.
bool onOther((Offset, Offset) s, Iterable<List<Offset>> others) {
  final (p, q) = s;
  for (final r in others) {
    for (var i = 1; i < r.length; i++) {
      final a = r[i - 1], b = r[i];
      if (p.dx == q.dx && a.dx == b.dx && (p.dx - a.dx).abs() < 1) {
        final lo = [p.dy, q.dy].reduce(math.min),
            hi = [p.dy, q.dy].reduce(math.max);
        final alo = [a.dy, b.dy].reduce(math.min),
            ahi = [a.dy, b.dy].reduce(math.max);
        if (lo < ahi - 1 && alo < hi - 1) return true;
      }
      if (p.dy == q.dy && a.dy == b.dy && (p.dy - a.dy).abs() < 1) {
        final lo = [p.dx, q.dx].reduce(math.min),
            hi = [p.dx, q.dx].reduce(math.max);
        final alo = [a.dx, b.dx].reduce(math.min),
            ahi = [a.dx, b.dx].reduce(math.max);
        if (lo < ahi - 1 && alo < hi - 1) return true;
      }
    }
  }
  return false;
}

/// Отрезки пути — от самого длинного к короткому: на них ищется место подписи.
List<(Offset, Offset)> segmentsByLength(List<Offset> pts) {
  final out = [for (var i = 1; i < pts.length; i++) (pts[i - 1], pts[i])];
  out.sort((x, y) => (y.$2 - y.$1).distance.compareTo((x.$2 - x.$1).distance));
  return out;
}

/// Очередь с приоритетом (двоичная куча): меньший приоритет — первым.
class _Heap {
  final _f = <int>[], _s = <int>[];

  bool get isNotEmpty => _f.isNotEmpty;

  void push(int f, int s) {
    _f.add(f);
    _s.add(s);
    var i = _f.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_f[p] <= _f[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  (int, int) pop() {
    final top = (_f[0], _s[0]);
    final lf = _f.removeLast(), ls = _s.removeLast();
    if (_f.isNotEmpty) {
      _f[0] = lf;
      _s[0] = ls;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _f.length && _f[l] < _f[m]) m = l;
        if (r < _f.length && _f[r] < _f[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final f = _f[a], s = _s[a];
    _f[a] = _f[b];
    _s[a] = _s[b];
    _f[b] = f;
    _s[b] = s;
  }
}
