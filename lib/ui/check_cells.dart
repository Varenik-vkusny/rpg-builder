// Ячейки проверки мира (вид А, срез 3): цвет + значок + число. Одно место для
// страницы мира, экрана «Проверка мира» и плана ассистента.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import 'theme.dart';

/// Цвет заливки и цвет значка/текста на нём для степени проблемы.
(Color, Color) severityColors(BuildContext context, Severity s) {
  if (s == Severity.error) {
    final c = Theme.of(context).colorScheme;
    return (c.error, c.onError);
  }
  final warn = AppColors.of(context).warn;
  final dark = ThemeData.estimateBrightnessForColor(warn) == Brightness.dark;
  return (warn, dark ? Colors.white : const Color(0xFF101114));
}

IconData severityIcon(Severity s) =>
    s == Severity.error ? Symbols.error_rounded : Symbols.warning_rounded;

/// Ячейка-значок цвета тяжести: слева в карточке проблемы (52 dp).
class SeverityCell extends StatelessWidget {
  const SeverityCell(this.severity, {super.key, this.width = 52});
  final Severity severity;
  final double width;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = severityColors(context, severity);
    return Container(
      width: width,
      color: bg,
      alignment: Alignment.center,
      child: Icon(severityIcon(severity), color: fg, fill: 1, size: 26),
    );
  }
}

/// Одна ячейка: значок и число, под ними подпись (если есть). Ноль — без
/// заливки, с зелёной галкой; больше нуля — заливка цвета степени.
class CheckCount extends StatelessWidget {
  const CheckCount({
    super.key,
    required this.severity,
    required this.count,
    this.label,
    this.big = false,
  });
  final Severity severity;
  final int count;
  final String? label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final zero = count == 0;
    final (bg, fg) = severityColors(context, severity);
    final textFg = zero ? Theme.of(context).colorScheme.onSurface : fg;
    return Container(
      color: zero ? null : bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(
                zero ? Symbols.check_rounded : severityIcon(severity),
                color: zero ? AppColors.of(context).ok : fg,
                fill: 1,
                size: 26,
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: textFg,
                  fontSize: big ? 30 : 26,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (label != null) ...[
            const SizedBox(height: 4),
            // Подпись не рвём по слогам: не влезла (узкий экран, крупный шрифт) — мельче.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label!,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: textFg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Полоса «Ошибки | Предупреждения | →». Есть onTap — справа ячейка 48 dp со
/// стрелкой и вся полоса нажимается; нет — просто итог.
class CheckStrip extends StatelessWidget {
  const CheckStrip({
    super.key,
    required this.errors,
    required this.warnings,
    this.big = false,
    this.onTap,
  });
  final int errors;
  final int warnings;
  final bool big;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final edge = BorderSide(color: s.outlineVariant);
    return Material(
      color: Colors.transparent,
      shape: Border.fromBorderSide(edge),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: big ? 72 : 60),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CheckCount(
                    key: const Key('check-errors'),
                    severity: Severity.error,
                    count: errors,
                    label: 'Ошибки',
                    big: big,
                  ),
                ),
                Expanded(
                  child: CheckCount(
                    key: const Key('check-warnings'),
                    severity: Severity.warning,
                    count: warnings,
                    label: 'Предупреждения',
                    big: big,
                  ),
                ),
                if (onTap != null)
                  Container(
                    width: 48,
                    decoration: BoxDecoration(border: Border(left: edge)),
                    child: Icon(
                      Symbols.chevron_right_rounded,
                      color: s.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
