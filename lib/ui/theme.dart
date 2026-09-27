// Тема приложения: Material 3, светлая и тёмная из одного зерна (PRODUCT.md — стандарт Android).
import 'package:flutter/material.dart';

const _seed = Color(0xFF415F91);

/// Смысловые цвета, которых нет в ColorScheme: предупреждение и «новое».
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.warn,
    required this.warnContainer,
    required this.onWarnContainer,
    required this.ok,
    required this.okContainer,
    required this.onOkContainer,
  });

  final Color warn;
  final Color warnContainer;
  final Color onWarnContainer;
  final Color ok;
  final Color okContainer;
  final Color onOkContainer;

  static const light = AppColors(
    warn: Color(0xFF7A5900),
    warnContainer: Color(0xFFFFDF9E),
    onWarnContainer: Color(0xFF261A00),
    ok: Color(0xFF1E6B3F),
    okContainer: Color(0xFFB6F2C8),
    onOkContainer: Color(0xFF00210F),
  );

  static const dark = AppColors(
    warn: Color(0xFFF5C04A),
    warnContainer: Color(0xFF4A3800),
    onWarnContainer: Color(0xFFFFDF9E),
    ok: Color(0xFF83D9A2),
    okContainer: Color(0xFF15512F),
    onOkContainer: Color(0xFFB6F2C8),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < .5 ? this : other ?? this;
}

ThemeData appTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  const stadium = StadiumBorder();
  const buttonSize = Size(64, 48);
  return ThemeData(
    colorScheme: scheme,
    extensions: [
      brightness == Brightness.dark ? AppColors.dark : AppColors.light,
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: buttonSize, shape: stadium),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: buttonSize, shape: stadium),
    ),
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 10,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
  );
}
