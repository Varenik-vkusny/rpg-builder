// Обложка объекта мира без картинок: ячейка с рамкой цвета объекта и большим значком.
import 'package:flutter/material.dart';

import 'theme.dart';

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
    final s = Theme.of(context).colorScheme;
    final hues = AppColors.of(context).coverHues;
    // Цвет — опознавательный знак объекта: рамка и приглушённый значок ячейки.
    final hueColor = hues[hue.round() % hues.length];
    return Material(
      color: s.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: hueColor, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned(
                right: 4,
                top: 0,
                // Значок приглушён: название может заходить под него.
                child: Icon(
                  icon,
                  size: 88,
                  color: hueColor.withValues(alpha: .35),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: _Caption(
                  title: title,
                  caption: caption,
                  counters: counters,
                  fg: s.onSurface,
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
  const _Caption({
    required this.title,
    this.caption,
    required this.counters,
    required this.fg,
  });
  final String title;
  final String? caption;
  final List<Counter> counters;
  final Color fg;

  @override
  Widget build(BuildContext context) {
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
          style: TextStyle(
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
                      style: TextStyle(
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
