// Прибор прокладки нитей (находка владельца на телефоне 17.10: нить к Слизню шла сквозь
// Бригадира — казалось, что «убить ×3» про него). Нить обходит чужие блоки, у нитей —
// свои полосы, подпись не ставится на участок, общий с другой нитью.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/holst_route.dart';
import 'package:rpg_builder/map/holst_threads.dart';

/// Отрезок [p]–[q] проходит сквозь прямоугольник [r] (по его внутренности).
bool crosses(Offset p, Offset q, Rect r) {
  final inner = r.deflate(1);
  final seg = Rect.fromPoints(p, q).inflate(.5);
  return seg.overlaps(inner);
}

void main() {
  test('путь — под прямым углом, концы на гранях, сквозь блоки не идёт', () {
    const a = Rect.fromLTWH(20, 600, 100, 48);
    const b = Rect.fromLTWH(20, 40, 148, 48);
    final blocks = [
      a,
      b,
      const Rect.fromLTWH(20, 200, 148, 48),
      const Rect.fromLTWH(20, 300, 148, 48),
      const Rect.fromLTWH(200, 250, 148, 48),
    ];
    final r = routeAround(a, b, blocks, const Size(380, 700))!;
    for (var i = 1; i < r.length; i++) {
      final p = r[i - 1], q = r[i];
      expect(p.dx == q.dx || p.dy == q.dy, isTrue, reason: '$r');
      for (final x in blocks.skip(2)) {
        expect(crosses(p, q, x), isFalse, reason: '$p–$q сквозь $x');
      }
    }
    bool onEdge(Rect x, Offset p) =>
        x.inflate(.01).contains(p) && !x.deflate(1).contains(p);
    expect(onEdge(a, r.first), isTrue);
    expect(onEdge(b, r.last), isTrue);
  });

  test('вторая нить идёт своей полосой, подпись — не на общем участке', () {
    // Обе цели справа за стеной: без полос вторая нить шла бы по первой почти целиком.
    const a = Rect.fromLTWH(20, 600, 100, 48);
    const b1 = Rect.fromLTWH(200, 40, 148, 48);
    const b2 = Rect.fromLTWH(200, 140, 148, 48);
    const wall = Rect.fromLTWH(0, 300, 340, 48);
    const area = Size(380, 700);
    final blocks = [a, b1, b2, wall];
    final r1 = routeAround(a, b1, blocks, area)!;
    final r2 = routeAround(a, b2, blocks, area, taken: pathCells(r1).toSet())!;
    // Сколько пути второй нити лежит на первой: меньше трети — своя полоса.
    final cells1 = pathCells(r1).toSet();
    final cells2 = pathCells(r2).toList();
    final common = cells2.where(cells1.contains).length;
    expect(common / cells2.length, lessThan(1 / 3), reason: '$r1 / $r2');
    expect(
      onOther(
        (const Offset(0, 0), const Offset(0, 100)),
        [
          [const Offset(0, 50), const Offset(0, 200)],
        ],
      ),
      isTrue,
    );
    expect(
      onOther(
        (const Offset(0, 0), const Offset(0, 100)),
        [
          [const Offset(8, 0), const Offset(8, 200)],
        ],
      ),
      isFalse,
    );
  });

  test(
    'подпись не встаёт на общий с другой нитью участок — только на свой',
    () {
      // Две нити с общим длинным стволом по x=100 и своими ветками вправо.
      const trunk = [Offset(100, 600), Offset(100, 100)];
      final one = ThreadSpec(
        a: const Rect.fromLTWH(80, 600, 40, 40),
        b: const Rect.fromLTWH(300, 80, 40, 40),
        label: 'выдаёт',
        tone: ThreadTone.hot,
        route: [...trunk, const Offset(300, 100)],
      );
      final two = ThreadSpec(
        a: const Rect.fromLTWH(80, 600, 40, 40),
        b: const Rect.fromLTWH(300, 280, 40, 40),
        label: 'убить ×3',
        tone: ThreadTone.hot,
        route: [trunk.first, const Offset(100, 300), const Offset(300, 300)],
      );
      for (final t in [one, two]) {
        final spot = placeLabel(t, [one, two], const Size(80, 22), [], 400)!;
        // Центр подписи — на ветке своей нити (горизонталь), а не на общем стволе x=100.
        expect(spot.center.dx, isNot(100), reason: t.label);
        expect(spot.center.dy, t.route!.last.dy, reason: t.label);
      }
    },
  );
}
