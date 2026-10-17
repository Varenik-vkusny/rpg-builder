// Холст мира (5е): сдвиг и масштаб. Кадр — матрица «мир → экран» (масштаб и сдвиг).
// Издалека (масштаб меньше 0.72) видны места с числами, вблизи — объекты.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Мельче этого масштаба — «издалека»: жетоны прячутся, на местах крупные числа.
const farScale = .72;
const minScale = .42, maxScale = 1.7;

/// Масштаб кадра — по оси x (по z он всегда 1, его брать нельзя).
double scaleOf(Matrix4 m) => m.storage[0];
Offset shiftOf(Matrix4 m) {
  final t = m.getTranslation();
  return Offset(t.x, t.y);
}

Matrix4 viewMatrix(double s, Offset t) => Matrix4.identity()
  ..translateByDouble(t.dx, t.dy, 0, 1)
  ..scaleByDouble(s, s, 1, 1);

/// Прямоугольник мира [r] на экране при кадре [m].
Rect toScreen(Matrix4 m, Rect r) {
  final s = scaleOf(m), t = shiftOf(m);
  return Rect.fromLTWH(
    t.dx + r.left * s,
    t.dy + r.top * s,
    r.width * s,
    r.height * s,
  );
}

/// Точка экрана [p] в координатах мира.
Offset toWorld(Matrix4 m, Offset p) => (p - shiftOf(m)) / scaleOf(m);

double _between(double v, double lo, double hi) =>
    math.min(math.max(v, lo), math.max(lo, hi));

/// Холст не уезжает целиком: от мест на экране остаётся хотя бы 80 dp.
Matrix4 clampView(Matrix4 m, Size vp, Rect b) {
  final s = scaleOf(m), t = shiftOf(m);
  return viewMatrix(
    s,
    Offset(
      _between(t.dx, 80 - b.right * s, vp.width - 80 - b.left * s),
      _between(t.dy, 80 - b.bottom * s, vp.height - 140 - b.top * s),
    ),
  );
}

/// Вблизи: масштаб 1, места по центру ширины, сверху.
Matrix4 nearView(Size vp, Rect b) =>
    viewMatrix(1, Offset((vp.width - b.width) / 2 - b.left, 12 - b.top));

/// Издалека: весь уровень в кадре над полкой, но не мельче 0.45 и не крупнее 0.62.
Matrix4 farView(Size vp, Rect b, double shelf) {
  final s = math
      .min((vp.height - shelf - 26) / b.height, (vp.width - 24) / b.width)
      .clamp(.45, .62);
  return viewMatrix(
    s,
    Offset(
      vp.width / 2 - b.center.dx * s,
      math.max(12, (vp.height - shelf) / 2 - b.center.dy * s),
    ),
  );
}

/// Кадр, где прямоугольник мира [r] стоит по центру видимой части при масштабе [s].
Matrix4 centerOn(Size vp, Rect r, double s, double shelf) => viewMatrix(
  s,
  Offset(
    vp.width / 2 - r.center.dx * s,
    math.max(8, (vp.height - shelf) / 2 - r.center.dy * s),
  ),
);

/// Масштаб вокруг точки экрана [focal]: точка мира под пальцем остаётся под пальцем.
Matrix4 zoomAround(Matrix4 start, Offset focal0, Offset focal, double k) {
  final s0 = scaleOf(start);
  final s = (s0 * k).clamp(minScale, maxScale);
  final w = toWorld(start, focal0);
  return viewMatrix(s, focal - w * s);
}
