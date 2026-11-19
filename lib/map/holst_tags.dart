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

/// Где встают метки [tags] на экране шириной [width]; [natural] — ширина метки целиком.
/// Вкладка своего жетона: сидит на его верхней грани от левого края, в один ряд со
/// значками; жетон обведён тем же цветом — одно целое (владелец 19.10).
/// Метка не уходит левее своего жетона и кончается до соседней метки справа, до края
/// экрана и до стрелки у края [arrows]; не влезла — короче, с многоточием (полностью
/// связь видна в нижней строке выбранного). 18.11 на полке метку Ключей у края экрана
/// сдвигало влево — на метку и рамку Кирки, на рамку выбранного квеста, на стрелку.
Map<TagSpec, Rect> tagRects(
  List<TagSpec> tags,
  double width,
  double Function(TagSpec) natural, {
  List<Offset> arrows = const [],
}) {
  bool sameRow(TagSpec a, TagSpec b) => (a.rect.top - b.rect.top).abs() < 18;
  final order = [...tags]..sort((a, b) => a.rect.left.compareTo(b.rect.left));
  final done = <TagSpec, Rect>{};
  for (final (n, tag) in order.indexed) {
    var left = math.max(4.0, tag.rect.left), right = width - 4;
    for (final o in order.skip(n + 1)) {
      if (sameRow(tag, o)) {
        right = math.min(right, math.max(4.0, o.rect.left) - 3);
        break;
      }
    }
    // Середина метки — на 1 ниже верха жетона; стрелка длиной 16 — по 8 в стороны.
    for (final a in arrows) {
      if ((a.dy - (tag.rect.top + 1)).abs() >= 18) continue;
      if (a.dx >= left) {
        right = math.min(right, a.dx - 10);
      } else {
        left = math.max(left, a.dx + 10);
      }
    }
    final w = math.max(18.0, math.min(natural(tag), right - left));
    done[tag] = Rect.fromLTWH(left, tag.rect.top - 8, w, 18);
  }
  return done;
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
    final placed = _layout(t.tags, size, [for (final e in t.edges) e.at]);
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

  void _arrow(Canvas canvas, Offset at, Offset dir, Color color) =>
      paintEdgeArrow(canvas, at, dir, color, colors.ink);

  /// Где встанут метки — см. [tagRects]; текст не влез — многоточие.
  List<(TagSpec, ({Rect rect, TextPainter? icon, TextPainter tp, double lead}))>
  _layout(List<TagSpec> tags, Size size, List<Offset> arrows) {
    final rects = tagRects(
      tags,
      size.width,
      (tag) => _measure(tag, double.infinity),
      arrows: arrows,
    );
    return [for (final tag in tags) (tag, _fit(tag, rects[tag]!))];
  }

  /// Ширина метки [tag], если текст не длиннее [max].
  double _measure(TagSpec tag, double max) {
    final lead = tag.icon == null
        ? 0.0
        : _glyph(tag.icon!, 14, colors.ink).width + 3;
    return lead + _text(tag.text, textStyle, max).width + 12;
  }

  ({Rect rect, TextPainter? icon, TextPainter tp, double lead}) _fit(
    TagSpec tag,
    Rect r,
  ) {
    final icon = tag.icon == null ? null : _glyph(tag.icon!, 14, colors.ink);
    final lead = icon == null ? 0.0 : icon.width + 3;
    final tp = _text(
      tag.text,
      textStyle.copyWith(color: colors.ink),
      math.max(0, r.width - 12 - lead),
    );
    return (rect: r, icon: icon, tp: tp, lead: lead);
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

/// Стрелка «там ещё связь» длиной 16 с острием по [dir]: обводка [ink], сверху цвет
/// связи. Та же рисуется на холсте у края и в легенде «?».
void paintEdgeArrow(
  Canvas canvas,
  Offset at,
  Offset dir,
  Color color,
  Color ink,
) {
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
    ..drawPath(path, line(ink, 6))
    ..drawPath(path, line(color, 2.5));
}

/// Образец стрелки для легенды «?».
class EdgeArrowSample extends CustomPainter {
  const EdgeArrowSample(this.color, this.ink);

  final Color color;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) => paintEdgeArrow(
    canvas,
    size.center(Offset.zero),
    const Offset(1, 1) / math.sqrt2,
    color,
    ink,
  );

  @override
  bool shouldRepaint(EdgeArrowSample old) =>
      old.color != color || old.ink != ink;
}
