// Рамка типа вокруг значка жетона (5д, выбор владельца 19.10): тип объекта читается формой,
// а не цветом — цвет занят местом и метками. Житель — гладкий круг, враг — круг с зубцами,
// предмет — квадрат; у события и квеста своих рамок нет.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glyphs.dart';
import 'holst_parts.dart' show tokenIcon;
import 'holst_scene.dart';

enum FrameShape { round, spiky, square }

FrameShape? frameOf(TokenKind k) => switch (k) {
  TokenKind.npc => FrameShape.round,
  TokenKind.enemy => FrameShape.spiky,
  TokenKind.item => FrameShape.square,
  TokenKind.event || TokenKind.quest => null,
};

/// Рамка 34 × 34 по центру своей области.
class TokenFramePainter extends CustomPainter {
  const TokenFramePainter(this.shape, this.color);

  final FrameShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    switch (shape) {
      case FrameShape.round:
        canvas.drawCircle(c, 16, paint);
      case FrameShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 31, height: 31),
            const Radius.circular(5),
          ),
          paint,
        );
      case FrameShape.spiky:
        // 10 зубцов: вершины на 17.5, впадины на 14.
        const teeth = 10;
        final path = Path();
        for (var k = 0; k < teeth * 2; k++) {
          final a = math.pi * k / teeth - math.pi / 2;
          final r = k.isEven ? 17.5 : 14.0;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), paint);
    }
  }

  @override
  bool shouldRepaint(TokenFramePainter old) =>
      old.shape != shape || old.color != color;
}

/// Значок внутри рамки: выбранный автором, а если его нет в наборе — по роли или виду.
Widget tokenGlyph(HolstToken t, double size, Color color) =>
    t.glyph != null && glyphName(t.glyph!) != null
    ? Glyph(t.glyph!, key: Key('glyph-${t.slug}'), size: size, color: color)
    : Icon(tokenIcon(t), size: size, color: color);

/// Значок в рамке типа 36 × 36; у события и квеста — просто значок.
Widget framedGlyph(HolstToken t, Color frame, Color ink, {Key? key}) =>
    switch (frameOf(t.kind)) {
      final shape? => CustomPaint(
        key: key,
        painter: TokenFramePainter(shape, frame),
        child: SizedBox.square(
          dimension: 36,
          child: Center(child: tokenGlyph(t, 19, ink)),
        ),
      ),
      null => Icon(
        tokenIcon(t),
        size: 22,
        color: ink,
        fill: t.kind == TokenKind.event ? 1 : 0,
      ),
    };
