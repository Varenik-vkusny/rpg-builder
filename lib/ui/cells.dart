// Плашки вида А «Лист»: значок + текст или число в ячейке с рамкой — вместо склеек «·».
import 'package:flutter/material.dart';

/// Описание одной плашки: значок, текст; [foe] — значок светлый (враги).
typedef CellSpec = ({IconData icon, String text, bool foe});

CellSpec cellSpec(IconData icon, String text, {bool foe = false}) =>
    (icon: icon, text: text, foe: foe);

/// Плашка: значок и текст в ячейке с рамкой. Слишком длинное — многоточие.
class Cell extends StatelessWidget {
  const Cell(this.icon, this.text, {super.key, this.foe = false});
  Cell.spec(CellSpec c, {Key? key})
    : this(c.icon, c.text, key: key, foe: c.foe);
  final IconData icon;
  final String text;
  final bool foe;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
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
          Icon(icon, size: 16, color: foe ? s.onSurface : s.onSurfaceVariant),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ряд плашек с переносом.
class Cells extends StatelessWidget {
  const Cells(this.cells, {super.key});
  final List<CellSpec> cells;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [for (final c in cells) Cell.spec(c)],
  );
}

/// Строка объекта вида А: ячейка со значком слева (52 dp), имя, плашки под ним.
class ObjRow extends StatelessWidget {
  const ObjRow({
    super.key,
    required this.icon,
    required this.title,
    this.cells = const [],
    this.onTap,
  });
  final IconData icon;
  final String title;
  final List<CellSpec> cells;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surfaceContainerLow,
      shape: RoundedRectangleBorder(side: BorderSide(color: s.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 52,
                color: s.surfaceContainerHighest,
                child: Icon(icon, size: 26, color: s.onSurface),
              ),
              Expanded(child: _RowBody(title, cells)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowBody extends StatelessWidget {
  const _RowBody(this.title, this.cells);
  final String title;
  final List<CellSpec> cells;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 6,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (cells.isNotEmpty) Cells(cells),
      ],
    ),
  );
}
