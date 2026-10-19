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

/// Метка у края: объект не виден, [at] — точка у края в его сторону.
typedef EdgeSpec = ({String id, Offset at, ThreadTone tone});

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
    c.dx.clamp(view.left + 8, view.right - 8),
    c.dy.clamp(view.top + 8, view.bottom - 8),
  );
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
    for (final b in t.badges) {
      _badge(canvas, b);
    }
    for (final tag in t.tags) {
      final icon = tag.icon == null ? null : _glyph(tag.icon!, 14, colors.ink);
      final lead = icon == null ? 0.0 : icon.width + 3;
      final tp = _text(
        tag.text,
        textStyle.copyWith(color: colors.ink),
        math.max(40, size.width - 16 - lead),
      );
      // Вкладка своего жетона: стоит на его верхней грани от левого края, а жетон обведён
      // тем же цветом — метка и рамка одно целое, не спутать с соседом (владелец 19.10).
      final w = lead + tp.width + 12, h = 20.0;
      final double left = tag.rect.left.clamp(
        4.0,
        math.max(4.0, size.width - w - 4),
      );
      final r = Rect.fromLTWH(left, tag.rect.top - h + 1, w, h);
      canvas.drawRect(
        tag.rect.deflate(1),
        fill(tag.tone)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawRect(r, fill(tag.tone));
      icon?.paint(canvas, Offset(r.left + 5, r.top + (h - icon.height) / 2));
      tp.paint(canvas, Offset(r.left + 6 + lead, r.top + (h - tp.height) / 2));
    }
    // Маленькая метка у края: «там ещё есть».
    for (final e in t.edges) {
      canvas.drawRect(
        Rect.fromCenter(center: e.at, width: 10, height: 10),
        fill(e.tone),
      );
    }
    for (final d in t.doors) {
      final r = d.rect;
      canvas.drawRect(
        Rect.fromLTWH(r.right - 14, r.top - 4, 10, 10),
        fill(d.tone),
      );
    }
  }

  /// Значки у правого верхнего угла жетона, справа налево.
  void _badge(Canvas canvas, BadgeSpec b) {
    const h = 18.0;
    var right = b.rect.right + 1;
    final style = textStyle.copyWith(fontSize: 10, color: chipInk);
    for (final c in b.chips.reversed) {
      final icon = c.icon == null ? null : _glyph(c.icon!, 12, chipInk);
      final tp = _text(c.text, style, 60);
      final w = 6.0 + (icon?.width ?? 0) + (c.text.isEmpty ? 0 : tp.width + 1);
      final r = Rect.fromLTWH(right - w, b.rect.top - 8, w, h);
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
      right = r.left - 2;
    }
  }

  @override
  bool shouldRepaint(TagPainter old) => true;
}
