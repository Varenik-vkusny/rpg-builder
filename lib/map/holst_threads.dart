// Холст мира (5е): нити под прямым углом со скошенными углами и квадратиками на концах;
// добыча — пунктир. Подпись нити никогда не ложится на блок: нет места — подписи нет
// (связь всё равно написана в нижней строке выбранного объекта).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme.dart';
import 'holst_route.dart';

/// Как выглядит нить: выбранного — белая, новая — зелёная, изменённая — пурпур, ошибка — красная.
enum ThreadTone { hot, isNew, changed, error }

/// Нить, готовая к рисованию: концы — прямоугольники в координатах слоя нитей.
class ThreadSpec {
  const ThreadSpec({
    required this.a,
    required this.b,
    required this.label,
    required this.tone,
    this.loot = false,
    this.aShelf = false,
    this.bShelf = false,
    this.route,
  });

  final Rect a;
  final Rect b;
  final String label;
  final ThreadTone tone;
  final bool loot;
  final bool aShelf;
  final bool bShelf;

  /// Проложенный путь в обход блоков; null — простая ломаная между концами.
  final List<Offset>? route;

  ThreadSpec withRoute(List<Offset>? r) => ThreadSpec(
    a: a,
    b: b,
    label: label,
    tone: tone,
    loot: loot,
    aShelf: aShelf,
    bShelf: bShelf,
    route: r,
  );
}

/// Точки ломаной между блоками: оба на полке — дугой над полкой; рядом по горизонтали —
/// из боковых граней; иначе — из верхней или нижней.
List<Offset> threadPoints(ThreadSpec s) {
  final a = s.a, b = s.b;
  final dx = b.center.dx - a.center.dx, dy = b.center.dy - a.center.dy;
  if (s.aShelf && s.bShelf) {
    final my = math.min(a.top, b.top) - 22;
    return [
      a.topCenter,
      Offset(a.center.dx, my),
      Offset(b.center.dx, my),
      b.topCenter,
    ];
  }
  if (dx.abs() >= dy.abs() && !s.aShelf && !s.bShelf) {
    final p = Offset(dx > 0 ? a.right : a.left, a.center.dy);
    final q = Offset(dx > 0 ? b.left : b.right, b.center.dy);
    final mx = (p.dx + q.dx) / 2;
    return [p, Offset(mx, p.dy), Offset(mx, q.dy), q];
  }
  final p = Offset(a.center.dx, dy > 0 ? a.bottom : a.top);
  final q = Offset(b.center.dx, dy > 0 ? b.top : b.bottom);
  final my = (p.dy + q.dy) / 2;
  return [p, Offset(p.dx, my), Offset(q.dx, my), q];
}

/// Ломаная со скошенными углами (срез до 9 px).
Path chamferPath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final a = pts[i - 1], b = pts[i], c = pts[i + 1];
    final l1 = (b - a).distance, l2 = (c - b).distance;
    final r = [9.0, l1 / 2, l2 / 2].reduce(math.min);
    if (r < 1) {
      path.lineTo(b.dx, b.dy);
      continue;
    }
    final p1 = b + (a - b) / l1 * r, p2 = b + (c - b) / l2 * r;
    path
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// Пунктир по пути: штрих 6, пропуск 4.
Path dashed(Path src) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += 10) {
      out.addPath(m.extractPath(d, math.min(d + 6, m.length)), Offset.zero);
    }
  }
  return out;
}

/// Цвета нитей — из темы.
class ThreadColors {
  const ThreadColors({
    required this.hot,
    required this.isNew,
    required this.changed,
    required this.error,
    required this.ink,
  });

  final Color hot, isNew, changed, error;

  /// Текст подписи на цветной плашке.
  final Color ink;

  Color of(ThreadTone t) => switch (t) {
    ThreadTone.hot => hot,
    ThreadTone.isNew => isNew,
    ThreadTone.changed => changed,
    ThreadTone.error => error,
  };
}

/// Цвета нитей холста — одни для холста и легенды «?».
ThreadColors threadColors(BuildContext context) {
  final s = Theme.of(context).colorScheme;
  final c = AppColors.of(context);
  return ThreadColors(
    hot: s.onSurface,
    isNew: c.ok,
    changed: c.change,
    error: s.error,
    ink: s.surfaceContainerLowest,
  );
}

/// Где встанет подпись: прямо на средней части своей нити (от [p] до [q]) — в середине
/// или ближе к концам, но не на блоках, не на других подписях и не за краем. Подпись
/// не отходит от нити: места нет — подписи нет, связь написана в нижней строке.
Rect? labelSpot(
  Offset p,
  Offset q,
  Size size,
  List<Rect> obstacles,
  double width,
) {
  for (final k in const [.5, .35, .65, .2, .8]) {
    final c = Offset.lerp(p, q, k)!;
    final r = Rect.fromCenter(
      center: c,
      width: size.width,
      height: size.height,
    );
    if (r.left < 4 || r.right > width - 4) continue;
    if (obstacles.any((o) => o.inflate(3).overlaps(r))) continue;
    return r;
  }
  return null;
}

/// Место подписи нити [t]: на её собственном участке (общие с другими нитями из [all]
/// — не годятся: там не понять, чья подпись), отрезки от длинного к короткому.
Rect? placeLabel(
  ThreadSpec t,
  List<ThreadSpec> all,
  Size size,
  List<Rect> busy,
  double width,
) {
  final route = t.route;
  if (route == null) {
    final pts = threadPoints(t);
    return labelSpot(pts[1], pts[2], size, busy, width);
  }
  final others = [
    for (final o in all)
      if (!identical(o, t) && o.route != null) o.route!,
  ];
  for (final s in segmentsByLength(route)) {
    if (onOther(s, others)) continue;
    final spot = labelSpot(s.$1, s.$2, size, busy, width);
    if (spot != null) return spot;
  }
  return null;
}

class ThreadPainter extends CustomPainter {
  ThreadPainter({
    required this.threads,
    required this.colors,
    required this.labels,
    required this.obstacles,
    required this.textStyle,
    super.repaint,
  });

  final List<ThreadSpec> Function() threads;
  final ThreadColors colors;

  /// Слой подписей рисуется поверх жетонов, слой нитей — под ними.
  final bool labels;
  final List<Rect> Function() obstacles;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final list = threads();
    final busy = labels ? obstacles() : <Rect>[];
    for (final t in list) {
      final pts = t.route ?? threadPoints(t);
      final color = colors.of(t.tone);
      if (!labels) {
        final path = chamferPath(pts);
        canvas.drawPath(
          t.loot ? dashed(path) : path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = t.tone == ThreadTone.hot ? 2.2 : 2.4,
        );
        for (final e in [pts.first, pts.last]) {
          canvas.drawRect(
            Rect.fromCenter(center: e, width: 7, height: 7),
            Paint()..color = color,
          );
        }
        continue;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: t.label,
          style: textStyle.copyWith(color: colors.ink),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final spot = placeLabel(
        t,
        list,
        Size(tp.width + 16, 22),
        busy,
        size.width,
      );
      if (spot == null) continue;
      busy.add(spot);
      canvas.drawRect(spot, Paint()..color = color);
      tp.paint(
        canvas,
        Offset(spot.left + 8, spot.top + (spot.height - tp.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(ThreadPainter old) => true;
}
