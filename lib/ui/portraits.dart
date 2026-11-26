// Плитки страницы объекта: характеристика и карточка-портрет в ленте.
import 'package:flutter/material.dart';

import 'parts.dart';

/// Плитка характеристики: значок, подпись, значение.
class StatTile extends StatelessWidget {
  const StatTile(this.icon, this.label, this.value, {super.key});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.surfaceContainerLow,
        border: Border.all(color: s.outlineVariant),
      ),
      // Значок и число сверху, подпись снизу во всю ширину: «Здоровье» не режется.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 18, color: s.onSurfaceVariant),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Карточка-портрет в ленте «Кто здесь» / «Добыча».
class PortraitCard extends StatelessWidget {
  const PortraitCard({
    super.key,
    required this.icon,
    required this.title,
    this.stats = const [],
    this.caption,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final List<(IconData, String)> stats;
  final String?
  caption; // одной строкой вместо чисел: в каком месте идёт событие
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return SizedBox(
      width: 104,
      child: Material(
        color: s.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: s.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            child: Column(
              spacing: 6,
              children: [
                Avatar(icon, size: 56),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                  )
                else if (stats.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (i, v) in stats)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 2,
                          children: [
                            Icon(i, size: 13, color: s.onSurfaceVariant),
                            Text(
                              v,
                              style: TextStyle(
                                fontSize: 12,
                                color: s.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
