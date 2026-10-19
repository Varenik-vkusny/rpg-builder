// Выбор значка вида (5д): группы набора, «Без значка» — вернуть значок по роли или виду.
// Цели 48 × 48; выбранный — в белой обводке; внизу — авторство набора.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'glyphs.dart';

/// Итог выбора: значок или null («Без значка»). Закрыли окно — сам выбор null.
typedef GlyphChoice = ({String? icon});

Future<GlyphChoice?> pickGlyph(
  BuildContext context, {
  required String title,
  required String? current,
}) => showModalBottomSheet<GlyphChoice>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _GlyphSheet(title: title, current: current),
);

class _GlyphSheet extends StatelessWidget {
  const _GlyphSheet({required this.title, required this.current});

  final String title;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget cell(String? id) {
      final on = id == current;
      return Tooltip(
        message: id == null ? 'без значка' : glyphName(id)!,
        child: InkWell(
          key: Key('glyph-pick-${id ?? 'none'}'),
          onTap: () => Navigator.pop(context, (icon: id)),
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.surfaceContainerHigh,
              border: on ? Border.all(color: s.onSurface, width: 2) : null,
            ),
            child: id == null
                ? Icon(
                    Symbols.block_rounded,
                    size: 22,
                    color: s.onSurfaceVariant,
                  )
                : Glyph(id, size: 28, color: s.onSurface),
          ),
        ),
      );
    }

    Widget head(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: s.onSurfaceVariant,
        ),
      ),
    );
    return SizedBox(
      key: const Key('glyph-sheet'),
      height: MediaQuery.sizeOf(context).height * .75,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Значок: $title',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          head('Без значка — по роли'),
          Align(alignment: Alignment.centerLeft, child: cell(null)),
          for (final (group, glyphs) in glyphGroups) ...[
            head(group),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final id in glyphs.keys) cell(id)],
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              glyphCredit,
              style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
