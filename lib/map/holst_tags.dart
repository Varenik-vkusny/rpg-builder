// Холст мира (5е): связи выбранного — метками на самих объектах (выбор владельца 17.10
// вместо нитей: «метки хороший вариант»). На связанном объекте — белая метка со словом
// связи. Объект не виден (полка за краем, холст за экраном) — маленькая белая метка у
// края в его сторону; объект за дверью — метка на двери. План «Менять», связь жеста и
// связь под колёсиком — такими же метками своего цвета (решение владельца 19.10 вместо нитей).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'holst_threads.dart';

/// Метка на объекте: где объект на экране и что написать.
typedef TagSpec = ({String id, Rect rect, String text, ThreadTone tone});

/// Метка у края: объект не виден, [at] — точка у края в его сторону.
typedef EdgeSpec = ({String id, Offset at, ThreadTone tone});

/// Метка на двери: за ней связанный объект.
typedef DoorSpec = ({Rect rect, ThreadTone tone});

/// Всё, что рисует слой меток.
typedef HolstTags = ({
  List<TagSpec> tags,
  List<EdgeSpec> edges,
  List<DoorSpec> doors,
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
    super.repaint,
  });

  final HolstTags Function() tags;
  final ThreadColors colors;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tags();
    Paint fill(ThreadTone tone) => Paint()..color = colors.of(tone);
    for (final tag in t.tags) {
      final tp = TextPainter(
        text: TextSpan(
          text: tag.text,
          style: textStyle.copyWith(color: colors.ink),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(40, size.width - 16));
      // Над жетоном, от края значка; не за краем экрана.
      final w = tp.width + 12, h = 20.0;
      final left = (tag.rect.left + 40).clamp(4.0, size.width - w - 4);
      final r = Rect.fromLTWH(left, tag.rect.top - h + 6, w, h);
      canvas.drawRect(r, fill(tag.tone));
      tp.paint(canvas, Offset(r.left + 6, r.top + (h - tp.height) / 2));
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

  @override
  bool shouldRepaint(TagPainter old) => true;
}
