// Детали карты-холста: точечная сетка поля, путь по уровням, подсказки пустого холста.
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/location.dart';
import '../content/nesting.dart';

/// Точечная сетка поля: едет и масштабируется вместе с холстом, при мелком масштабе
/// редеет, чтобы не превращаться в серый туман.
class DotGrid extends CustomPainter {
  DotGrid(this.view, this.color) : super(repaint: view);
  final TransformationController view;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final m = view.value;
    final k = m.getMaxScaleOnAxis();
    var step = 24 * k;
    while (step < 14) {
      step *= 2;
    }
    final t = m.getTranslation();
    final ox = t.x % step, oy = t.y % step;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final points = <Offset>[
      for (var x = ox; x < size.width; x += step)
        for (var y = oy; y < size.height; y += step) Offset(x, y),
    ];
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(DotGrid old) => old.color != color;
}

/// Пустой уровень — подсказка, что делать, а не пустое поле.
class EmptyWorld extends StatelessWidget {
  const EmptyWorld({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Center(
      key: const Key('map-empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Symbols.map_rounded, size: 56, color: s.outline),
            Text(
              'Мест пока нет',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Создай место в мире или попроси ассистента — '
              'оно само встанет на карту.',
              textAlign: TextAlign.center,
              style: TextStyle(color: s.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Место без вложенных — подсказка, что сюда можно положить, а не пустое поле (5а.5).
class EmptyLevel extends StatelessWidget {
  const EmptyLevel({super.key, required this.place, required this.depth});
  final Location place;

  /// Уровень места: верхний — 1. На последнем уровне класть внутрь нельзя.
  final int depth;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final last = depth >= maxNestingDepth;
    return Center(
      key: const Key('map-empty-level'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Symbols.stacks_rounded, size: 56, color: s.outline),
            Text(
              'Внутри «${place.title}» пусто',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              last
                  ? 'Это $maxNestingDepth-й уровень — глубже места не кладутся.'
                  : 'Создай место и в поле «Внутри места» выбери '
                        '«${place.title}» — оно появится здесь.',
              textAlign: TextAlign.center,
              style: TextStyle(color: s.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Путь сверху: «Карта › Копи › Штольня №3». Нажатие на часть — туда; последняя — где ты.
class MapPath extends StatelessWidget {
  const MapPath({super.key, required this.path, required this.onGo});
  final List<Location> path;

  /// Сколько мест пути оставить: 0 — верхний уровень.
  final ValueChanged<int> onGo;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget part(String text, Key key, int keep) {
      final here = keep == path.length;
      return InkWell(
        key: key,
        onTap: here ? null : () => onGo(keep),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              widthFactor: 1,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: here ? FontWeight.w600 : FontWeight.w400,
                  color: here ? s.onSurface : s.primary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      key: const Key('map-path'),
      color: s.surfaceContainerLow,
      // Короткий путь — слева; длинный листается, виден его конец — где ты сейчас.
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  part('Карта', const Key('crumb-root'), 0),
                  for (final (i, l) in path.indexed) ...[
                    Text('›', style: TextStyle(color: s.outline, fontSize: 15)),
                    part(l.title, Key('crumb-${l.slug}'), i + 1),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
