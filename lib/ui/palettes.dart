// Стиль «Телетекст на графите» (выбор владельца 28.09): каждый цвет — один смысл.
// Голубой — только главные действия; жёлтый — предупреждение; красный — ошибка;
// зелёный — новое; пурпурный — изменено.
import 'package:flutter/material.dart';

/// Все цвета одной темы. Поверхности — от самой глубокой к самой высокой.
class Palette {
  const Palette({
    required this.surface,
    required this.lowest,
    required this.low,
    required this.container,
    required this.high,
    required this.highest,
    required this.on,
    required this.onVariant,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.change,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.warn,
    required this.warnContainer,
    required this.onWarnContainer,
    required this.ok,
    required this.okContainer,
    required this.onOkContainer,
    required this.coverHues,
  });

  final Color surface, lowest, low, container, high, highest;
  final Color on, onVariant, outline, outlineVariant;
  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;

  /// «Изменено» и «СТАЛО» — пурпурный: голубой занят главными действиями.
  final Color change;
  final Color error, onError, errorContainer, onErrorContainer;
  final Color warn, warnContainer, onWarnContainer;
  final Color ok, okContainer, onOkContainer;

  /// Свой цвет места (рамка и значок обложки): приглушённые оттенки вдали от смысловых —
  /// голубого, пурпурного, красного, жёлтого, зелёного (владелец 29.09). Прибор place_colors_test.
  final List<Color> coverHues;

  ColorScheme scheme(Brightness b) => ColorScheme(
    brightness: b,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: onVariant,
    onSecondary: surface,
    secondaryContainer: high,
    onSecondaryContainer: on,
    tertiary: onVariant,
    onTertiary: surface,
    tertiaryContainer: high,
    onTertiaryContainer: on,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: on,
    onSurfaceVariant: onVariant,
    surfaceDim: lowest,
    surfaceBright: highest,
    surfaceContainerLowest: lowest,
    surfaceContainerLow: low,
    surfaceContainer: container,
    surfaceContainerHigh: high,
    surfaceContainerHighest: highest,
    outline: outline,
    outlineVariant: outlineVariant,
    inverseSurface: on,
    onInverseSurface: surface,
    inversePrimary: primaryContainer,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    scrim: Colors.black,
  );
}

/// Форма деталей и шрифты: прямые углы, детали — рамкой по контуру (ячейки).
@immutable
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle();

  /// Метки, поля, кнопки / плашки, плитки / обложки, листы. Телетекст — без скруглений.
  final double radiusS = 0, radiusM = 0, radiusL = 0;

  /// Основной шрифт — всё, кроме крупных заголовков.
  final String body = 'GolosText';

  /// Широкий шрифт — только крупные заголовки (план, окна).
  final String display = 'Unbounded';

  static AppStyle of(BuildContext context) =>
      Theme.of(context).extension<AppStyle>() ?? const AppStyle();

  @override
  AppStyle copyWith() => this;

  @override
  AppStyle lerp(AppStyle? other, double t) => this;
}

/// Тёмный графит, не чёрный: поверхности на ступень светлее фона.
const darkPalette = Palette(
  surface: Color(0xFF15161A),
  lowest: Color(0xFF101114),
  low: Color(0xFF1C1D22),
  container: Color(0xFF222329),
  high: Color(0xFF2A2C33),
  highest: Color(0xFF33353D),
  on: Color(0xFFF1F1F3),
  onVariant: Color(0xFFB4B6BE),
  outline: Color(0xFF8A8D96),
  outlineVariant: Color(0xFF3A3C44),
  primary: Color(0xFF00E0E0),
  onPrimary: Color(0xFF001E1E),
  primaryContainer: Color(0xFF003D3D),
  onPrimaryContainer: Color(0xFFA6FFFF),
  change: Color(0xFFF07CF0),
  error: Color(0xFFFF5C5C),
  onError: Color(0xFF1A0000),
  errorContainer: Color(0xFF4A1111),
  onErrorContainer: Color(0xFFFFD6D6),
  warn: Color(0xFFFFE14D),
  warnContainer: Color(0xFF3B3500),
  onWarnContainer: Color(0xFFFFF3A0),
  ok: Color(0xFF4CEB86),
  okContainer: Color(0xFF0E3B1E),
  onOkContainer: Color(0xFFBDFFD2),
  // Тёплых оттенков нет: все они между красной ошибкой и жёлтым предупреждением.
  coverHues: [
    Color(0xFF7084B4), // сланцево-синий
    Color(0xFF8680BC), // индиго
    Color(0xFF9E86BA), // фиалковый
    Color(0xFF7A8FB0), // стальной
    Color(0xFF93949A), // серый
  ],
);

/// Светлая — запасная (основная тема тёмная): те же смыслы, тёмные оттенки.
const lightPalette = Palette(
  surface: Color(0xFFF4F4F6),
  lowest: Color(0xFFFFFFFF),
  low: Color(0xFFECECEF),
  container: Color(0xFFE5E5E9),
  high: Color(0xFFDDDDE2),
  highest: Color(0xFFD4D4DA),
  on: Color(0xFF16171A),
  onVariant: Color(0xFF44464D),
  outline: Color(0xFF70737B),
  outlineVariant: Color(0xFFC4C5CB),
  primary: Color(0xFF006B6B),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFB8F5F5),
  onPrimaryContainer: Color(0xFF002020),
  change: Color(0xFF9A1F9A),
  error: Color(0xFFC00000),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFD6D6),
  onErrorContainer: Color(0xFF3D0000),
  warn: Color(0xFF7A6A00),
  warnContainer: Color(0xFFFFF59E),
  onWarnContainer: Color(0xFF231F00),
  ok: Color(0xFF0B7A33),
  okContainer: Color(0xFFC6FFD6),
  onOkContainer: Color(0xFF002910),
  coverHues: [
    Color(0xFF4A5670),
    Color(0xFF55537A),
    Color(0xFF66577A),
    Color(0xFF4A5A74),
    Color(0xFF5E5F64),
  ],
);
