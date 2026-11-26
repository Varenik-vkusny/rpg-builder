// Строка находки в справочнике (вид А): ячейка со значком вида слева, имя крупно,
// ниже ячейки-плашки с числами и словами, источник — значком, стрелка справа.
// Английского дубля в строке нет: оригинал виден в карточке («Оригинал»).
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../assistant/history_line.dart' show Source, sourceIcon;

/// Одна ячейка-плашка строки: значок (если есть) и короткий текст.
class ResultCell extends StatelessWidget {
  const ResultCell({super.key, this.icon, this.text, this.tip});

  final IconData? icon;
  final String? text;

  /// Подсказка по долгому нажатию (для значка без текста — что он значит).
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final cell = Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: s.surfaceContainer,
        border: Border.all(color: s.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (icon != null) Icon(icon, size: 16, color: s.onSurfaceVariant),
          if (text != null)
            Text(
              text!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
    return tip == null ? cell : Tooltip(message: tip!, child: cell);
  }
}

/// Строка находки: [icon] — значок вида, [title] — имя по-русски, [cells] — плашки.
class ResultRow extends StatelessWidget {
  const ResultRow({
    super.key,
    required this.icon,
    required this.title,
    required this.cells,
    required this.source,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<Widget> cells;

  /// Название источника (документ справочника) — подсказка к значку источника.
  final String source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: s.surfaceContainerLow,
        shape: Border.all(color: s.outlineVariant),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  color: s.surfaceContainerHighest,
                  child: Icon(icon, size: 28, color: s.onSurface),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...cells,
                            ResultCell(
                              key: const Key('open5e-source'),
                              icon: sourceIcon(Source.import),
                              tip: source,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
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
