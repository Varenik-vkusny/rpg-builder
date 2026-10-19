// Холст мира (5е): цвета связей — белый у выбранного, зелёный у новой, пурпур у
// изменённой; пунктир — для добычи и полосы палитры. Нитей на холсте
// больше нет: связи — метками на объектах (выбор владельца 17.10 и 19.10).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Цвет связи: выбранного — белый, новая — зелёный, изменённая — пурпур.
enum ThreadTone { hot, isNew, changed }

/// Пунктир по пути: штрих 6, пропуск 4.
Path dashed(Path src) {
  final out = Path();
  for (final m in src.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += 10) {
      out.addPath(m.extractPath(d, math.min(d + 6, m.length)), Offset.zero);
    }
  }
  return out;
}

/// Цвета связей — из темы.
class ThreadColors {
  const ThreadColors({
    required this.hot,
    required this.isNew,
    required this.changed,
    required this.ink,
  });

  final Color hot, isNew, changed;

  /// Текст на цветной метке.
  final Color ink;

  Color of(ThreadTone t) => switch (t) {
    ThreadTone.hot => hot,
    ThreadTone.isNew => isNew,
    ThreadTone.changed => changed,
  };
}

/// Цвета связей холста — одни для меток и легенды «?».
ThreadColors threadColors(BuildContext context) {
  final s = Theme.of(context).colorScheme;
  final c = AppColors.of(context);
  return ThreadColors(
    hot: s.onSurface,
    isNew: c.ok,
    changed: c.change,
    ink: s.surfaceContainerLowest,
  );
}
