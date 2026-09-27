// Обложка объекта мира без картинок: цвет по оттенку, диагональный узор, большой значок.
import 'package:flutter/material.dart';

/// Счётчик на обложке: значок и число («💀 2»).
typedef Counter = (IconData, int);

class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.title,
    required this.icon,
    required this.hue,
    this.counters = const [],
    this.caption,
    this.onTap,
    this.height = 128,
  });

  final String title;
  final IconData icon;

  /// Оттенок 0–360: у каждого объекта свой, одинаковый между запусками.
  final double hue;
  final List<Counter> counters;
  final String? caption;
  final VoidCallback? onTap;
  final double height;

  /// Оттенок из названия: одно и то же название — один и тот же цвет.
  static double hueOf(String seed) =>
      (seed.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0xffff) % 360)
          .toDouble();

  @override
  Widget build(BuildContext context) {
    final top = HSLColor.fromAHSL(1, hue, .38, .42).toColor();
    final bottom = HSLColor.fromAHSL(1, hue, .36, .22).toColor();
    const fg = Colors.white;
    return Material(
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [top, bottom],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _Stripes())),
              Positioned(
                right: 4,
                top: 0,
                child: Icon(icon, size: 88, color: fg.withValues(alpha: .22)),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: _Caption(
                  title: title,
                  caption: caption,
                  counters: counters,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Подпись обложки: строка над названием, название, счётчики.
class _Caption extends StatelessWidget {
  const _Caption({required this.title, this.caption, required this.counters});
  final String title;
  final String? caption;
  final List<Counter> counters;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        if (caption case final c?)
          Text(
            c,
            style: TextStyle(color: fg.withValues(alpha: .85), fontSize: 13),
          ),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: fg,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        if (counters.isNotEmpty)
          Row(
            spacing: 12,
            children: [
              for (final (i, n) in counters)
                Row(
                  spacing: 4,
                  children: [
                    Icon(i, size: 17, color: fg),
                    Text(
                      '$n',
                      style: const TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class _Stripes extends CustomPainter {
  const _Stripes();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x10FFFFFF)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 13) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => false;
}
