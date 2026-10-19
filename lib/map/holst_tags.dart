// Холст мира (5е): связи выбранного — метками на самих объектах (выбор владельца 17.10
// вместо нитей: «метки хороший вариант»). На связанном объекте — белая метка со словом
// связи. Объект не виден (полка за краем, холст за экраном) — маленькая белая метка у
// края в его сторону; объект за дверью — метка на двери. План «Менять», связь жеста и
// связь под колёсиком — такими же метками своего цвета, с именем первого конца; в покое —
// значки, откуда у объекта связи (вариант Б владельца 19.10).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'holst_threads.dart';

/// Метка на объекте: где объект на экране и что написать.
typedef TagSpec = ({
  String id,
  Rect rect,
  String text,
  ThreadTone tone,
  IconData? icon,
});

/// Метка у края: объект не виден. [at] — середина стрелки у края, [dir] — куда она
/// смотрит (на полке — по диагонали вниз в сторону спрятанного, владелец 19.10).
typedef EdgeSpec = ({String id, Offset at, Offset dir, ThreadTone tone});

/// Метка на двери: за ней связанный объект.
typedef DoorSpec = ({Rect rect, ThreadTone tone});

/// Значки в покое на объекте: значок второго конца связи и короткая надпись.
typedef BadgeSpec = ({Rect rect, List<({IconData? icon, String text})> chips});

/// Всё, что рисует слой меток.
typedef HolstTags = ({
  List<TagSpec> tags,
  List<EdgeSpec> edges,
  List<DoorSpec> doors,
  List<BadgeSpec> badges,
});

/// Точка у края области [view] в сторону прямоугольника [r], который за ней.
Offset edgePoint(Rect view, Rect r) {
  final c = r.center;
  return Offset(
    c.dx.clamp(view.left + 14, view.right - 14),
    c.dy.clamp(view.top + 14, view.bottom - 14),
  );
}

/// Единичный вектор от [from] к [to]; совпали — вверх.
Offset towards(Offset from, Offset to) {
  final d = to - from;
  return d.distance < 1 ? const Offset(0, -1) : d / d.distance;
}

class TagPainter extends CustomPainter {
  TagPainter({
    required this.tags,
    required this.colors,
    required this.textStyle,
    required this.chipFill,
    required this.chipLine,
    required this.chipInk,
    super.repaint,
  });

  final HolstTags Function() tags;
  final ThreadColors colors;
  final TextStyle textStyle;

  /// Значки в покое: тихие — фон, рамка и текст из темы, не цвет связи.
  final Color chipFill, chipLine, chipInk;

  TextPainter _text(String text, TextStyle style, double max) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: max);

  TextPainter _glyph(IconData i, double size, Color color) => TextPainter(
    text: TextSpan(
      text: String.fromCharCode(i.codePoint),
      style: TextStyle(
        fontFamily: i.fontFamily,
        package: i.fontPackage,
        fontSize: size,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final t = tags();
    Paint fill(ThreadTone tone) => Paint()..color = colors.of(tone);
    // Сначала где встанут метки: значок, на который легла метка, не рисуется обрезком.
    final placed = [for (final tag in t.tags) (tag, _tagRect(tag, size))];
    final covered = [for (final (_, p) in placed) p.rect];
    for (final b in t.badges) {
      _badge(canvas, b, covered);
    }
    for (final (tag, p) in placed) {
      final (rect: r, :icon, :tp, :lead) = p;
      canvas.drawRect(
        tag.rect.deflate(1),
        fill(tag.tone)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawRect(r, fill(tag.tone));
      icon?.paint(
        canvas,
        Offset(r.left + 5, r.top + (r.height - icon.height) / 2),
      );
      tp.paint(
        canvas,
        Offset(r.left + 6 + lead, r.top + (r.height - tp.height) / 2),
      );
    }
    // Стрелка у края: «там ещё есть» — с тёмной обводкой, чтобы читалась на любом фоне.
    for (final e in t.edges) {
      _arrow(canvas, e.at, e.dir, colors.of(e.tone));
    }
    for (final d in t.doors) {
      final r = d.rect;
      canvas.drawRect(
        Rect.fromLTWH(r.right - 14, r.top - 4, 10, 10),
        fill(d.tone),
      );
    }
  }

  /// Стрелка длиной 16 с острием по [dir]: обводка цвета текста меток, сверху цвет связи.
  void _arrow(Canvas canvas, Offset at, Offset dir, Color color) {
    final tip = at + dir * 8, tail = at - dir * 8;
    Offset turn(double a) => Offset(
      dir.dx * math.cos(a) - dir.dy * math.sin(a),
      dir.dx * math.sin(a) + dir.dy * math.cos(a),
    );
    final path = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(tip.dx, tip.dy);
    for (final a in const [2.5, -2.5]) {
      final h = tip + turn(a) * 7;
      path
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(h.dx, h.dy);
    }
    Paint line(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(path, line(colors.ink, 6))
      ..drawPath(path, line(color, 2.5));
  }

  /// Где встанет метка. Вкладка своего жетона: сидит на его верхней грани от левого края,
  /// в один ряд со значками; жетон обведён тем же цветом — одно целое (владелец 19.10).
  ({Rect rect, TextPainter? icon, TextPainter tp, double lead}) _tagRect(
    TagSpec tag,
    Size size,
  ) {
    final icon = tag.icon == null ? null : _glyph(tag.icon!, 14, colors.ink);
    final lead = icon == null ? 0.0 : icon.width + 3;
    final tp = _text(
      tag.text,
      textStyle.copyWith(color: colors.ink),
      math.max(40, size.width - 16 - lead),
    );
    final w = lead + tp.width + 12;
    final double left = tag.rect.left.clamp(
      4.0,
      math.max(4.0, size.width - w - 4),
    );
    return (
      rect: Rect.fromLTWH(left, tag.rect.top - 8, w, 18),
      icon: icon,
      tp: tp,
      lead: lead,
    );
  }

  /// Значки у правого верхнего угла жетона, справа налево; под меткой — не рисуются.
  void _badge(Canvas canvas, BadgeSpec b, List<Rect> covered) {
    const h = 18.0;
    var right = b.rect.right + 1;
    final style = textStyle.copyWith(fontSize: 10, color: chipInk);
    for (final c in b.chips.reversed) {
      final icon = c.icon == null ? null : _glyph(c.icon!, 12, chipInk);
      final tp = _text(c.text, style, 60);
      final w = 6.0 + (icon?.width ?? 0) + (c.text.isEmpty ? 0 : tp.width + 1);
      final r = Rect.fromLTWH(right - w, b.rect.top - 8, w, h);
      right = r.left - 2;
      if (covered.any((x) => x.overlaps(r))) continue;
      canvas.drawRect(r, Paint()..color = chipFill);
      canvas.drawRect(
        r.deflate(.5),
        Paint()
          ..color = chipLine
          ..style = PaintingStyle.stroke,
      );
      var x = r.left + 3;
      if (icon != null) {
        icon.paint(canvas, Offset(x, r.top + (h - icon.height) / 2));
        x += icon.width + 1;
      }
      tp.paint(canvas, Offset(x, r.top + (h - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(TagPainter old) => true;
}
