// Тема приложения: одна на всё. Каркас — Material 3 (жесты Android), стиль — «Телетекст
// на графите» (palettes.dart): прямые углы, детали-ячейки, голубой — только главные действия.
import 'package:flutter/material.dart';

import 'palettes.dart';

export 'palettes.dart' show AppStyle;

/// Смысловые цвета, которых нет в ColorScheme: предупреждение, «новое», «изменено».
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.warn,
    required this.warnContainer,
    required this.onWarnContainer,
    required this.ok,
    required this.okContainer,
    required this.onOkContainer,
    required this.change,
    required this.coverHues,
  });

  AppColors.from(Palette p)
    : this(
        warn: p.warn,
        warnContainer: p.warnContainer,
        onWarnContainer: p.onWarnContainer,
        ok: p.ok,
        okContainer: p.okContainer,
        onOkContainer: p.onOkContainer,
        change: p.change,
        coverHues: p.coverHues,
      );

  final Color warn;
  final Color warnContainer;
  final Color onWarnContainer;
  final Color ok;
  final Color okContainer;
  final Color onOkContainer;

  /// «Изменено», «СТАЛО».
  final Color change;

  /// Цвета обложек: только свободные от смысла.
  final List<Color> coverHues;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.from(darkPalette);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < .5 ? this : other ?? this;
}

ThemeData appTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? darkPalette : lightPalette;
  const st = AppStyle();
  final s = p.scheme(brightness);

  const square = RoundedRectangleBorder();
  final hairline = BorderSide(color: s.outlineVariant);
  const buttonSize = Size(64, 48);
  final label = TextStyle(
    fontFamily: st.body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: .1,
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 12);
  // Вторичные действия («+ Добавить шаг», «По одному», «Отмена») — светлым, не голубым.
  final quiet = TextButton.styleFrom(
    shape: square,
    textStyle: label,
    foregroundColor: s.onSurface,
  );

  final base = ThemeData(
    colorScheme: s,
    fontFamily: st.body,
    scaffoldBackgroundColor: s.surface,
  );
  // Широкий Unbounded — только крупные заголовки (заголовок плана, окна).
  final big = TextStyle(fontFamily: st.display, fontWeight: FontWeight.w600);
  final text = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.merge(big),
    headlineMedium: base.textTheme.headlineMedium?.merge(big),
    headlineSmall: base.textTheme.headlineSmall
        ?.merge(big)
        .copyWith(fontSize: 20),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 17,
    ),
  );

  return base.copyWith(
    textTheme: text,
    extensions: [AppColors.from(p), st],
    appBarTheme: AppBarTheme(
      backgroundColor: s.surface,
      foregroundColor: s.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // Меньше зазор после «назад»: «Изменить персонажа» влезает и при крупном шрифте.
      titleSpacing: 4,
      titleTextStyle: text.titleLarge?.copyWith(color: s.onSurface),
      shape: Border(bottom: hairline),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: s.surfaceContainerLow,
      shape: RoundedRectangleBorder(side: hairline),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: square,
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        shape: square,
        textStyle: label,
        foregroundColor: s.onSurface,
        side: BorderSide(color: s.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: quiet),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: buttonSize,
        shape: square,
        textStyle: label,
        elevation: 0,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: square),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      shape: square,
      backgroundColor: s.primary,
      foregroundColor: s.onPrimary,
      extendedTextStyle: label,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(side: hairline),
      labelStyle: TextStyle(fontFamily: st.body, fontSize: 13),
      // Значок чипа — светлый: чип сообщает, а не зовёт к главному действию.
      iconTheme: IconThemeData(color: s.onSurfaceVariant, size: 18),
    ),
    // Выбранный вариант — отметка светлым: это состояние, а не действие.
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? s.onSurface
            : s.onSurfaceVariant,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? s.onSurface : null,
      ),
      checkColor: WidgetStatePropertyAll(s.surface),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: s.onSurfaceVariant,
    ),
    inputDecorationTheme: InputDecorationTheme(
      // Ячейка-заливка с линией снизу: подпись внутри ячейки не режется в узких полях.
      filled: true,
      contentPadding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
      fillColor: s.surfaceContainer,
      border: UnderlineInputBorder(borderSide: BorderSide(color: s.outline)),
      enabledBorder: UnderlineInputBorder(borderSide: hairline),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: s.onSurface, width: 2),
      ),
      floatingLabelStyle: TextStyle(color: s.onSurfaceVariant),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: s.onSurface,
      selectionColor: s.outline,
      selectionHandleColor: s.onSurface,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 10,
      shape: square,
    ),
    dividerTheme: DividerThemeData(color: s.outlineVariant, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: s.surfaceContainerLow,
      shape: RoundedRectangleBorder(side: BorderSide(color: s.outline)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(side: BorderSide(color: s.outline)),
      backgroundColor: s.surfaceContainerHigh,
      titleTextStyle: text.headlineSmall?.copyWith(color: s.onSurface),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: square,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.surfaceContainer,
      indicatorColor: s.surfaceContainerHighest,
      indicatorShape: square,
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(shape: WidgetStatePropertyAll(square)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: s.onSurface,
      thumbColor: s.onSurface,
      inactiveTrackColor: s.outlineVariant,
    ),
  );
}
