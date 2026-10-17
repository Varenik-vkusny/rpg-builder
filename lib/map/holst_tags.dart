// Холст мира (5е): связи выбранного — метками на самих объектах (выбор владельца 17.10
// вместо нитей: «метки хороший вариант»). На связанном объекте — белая метка со словом
// связи. Объект не виден (полка за краем, холст за экраном) — маленькая белая метка у
// края в его сторону; объект за дверью — метка на двери.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Метка на объекте: где объект на экране и что написать.
typedef TagSpec = ({String id, Rect rect, String text});

/// Метка у края: объект не виден, [at] — точка у края в его сторону.
typedef EdgeSpec = ({String id, Offset at});

/// Всё, что рисует слой меток.
typedef HolstTags = ({
  List<TagSpec> tags,
  List<EdgeSpec> edges,
  List<Rect> doors,
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
    required this.ink,
    required this.paper,
    required this.textStyle,
    super.repaint,
  });

  final HolstTags Function() tags;
  final Color ink;
  final Color paper;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tags();
    final fill = Paint()..color = paper;
    for (final tag in t.tags) {
      final tp = TextPainter(
        text: TextSpan(
          text: tag.text,
          style: textStyle.copyWith(color: ink),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(40, size.width - 16));
      // Над жетоном, от края значка; не за краем экрана.
      final w = tp.width + 12, h = 20.0;
      final left = (tag.rect.left + 40).clamp(4.0, size.width - w - 4);
      final r = Rect.fromLTWH(left, tag.rect.top - h + 6, w, h);
      canvas.drawRect(r, fill);
      tp.paint(canvas, Offset(r.left + 6, r.top + (h - tp.height) / 2));
    }
    // Маленькая метка у края: «там ещё есть».
    for (final e in t.edges) {
      canvas.drawRect(
        Rect.fromCenter(center: e.at, width: 10, height: 10),
        fill,
      );
    }
    for (final d in t.doors) {
      canvas.drawRect(Rect.fromLTWH(d.right - 14, d.top - 4, 10, 10), fill);
    }
  }

  @override
  bool shouldRepaint(TagPainter old) => true;
}
