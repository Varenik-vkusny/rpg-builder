// Враги на экране образцов (5д): строка находки и карточка «каким станет враг» перед
// импортом — числа, значок, источник; новые проблемы мира — плашками, как у правки.
import 'package:flutter/material.dart';

import '../check/world_check.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../map/glyphs.dart';
import '../ui/parts.dart';
import 'open5e_api.dart';
import 'open5e_enemy.dart';
import 'open5e_result_row.dart';

String _cr(double cr) => switch (cr) {
  0.125 => '1/8',
  0.25 => '1/4',
  0.5 => '1/2',
  _ => '${cr.round()}',
};

/// Строка находки: имя по-русски [title]; опасность и здоровье ячейками; оригинал — в карточке.
Widget enemyTile(Open5eCreature c, String title, VoidCallback onTap) =>
    ResultRow(
      key: Key('open5e-${c.key}'),
      icon: Symbols.skull_rounded,
      title: title,
      source: c.document,
      cells: [
        ResultCell(
          icon: Symbols.military_tech_rounded,
          text: _cr(c.challenge),
          tip: 'Опасность',
        ),
        ResultCell(
          icon: Symbols.favorite_rounded,
          text: '${c.hp}',
          tip: 'Здоровье',
        ),
      ],
      onTap: onTap,
    );

/// Каким враг придёт в мир под именем [title]; [problems] — что появится в мире после импорта.
class EnemyPreview extends StatelessWidget {
  const EnemyPreview({
    super.key,
    required this.c,
    required this.title,
    required this.problems,
  });

  final Open5eCreature c;
  final String title;
  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final glyph = glyphOf(c);
    Widget row(String label, String value) => Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(color: s.onSurfaceVariant)),
        ),
        Expanded(child: Text(value)),
      ],
    );
    return Column(
      key: const Key('open5e-enemy-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            if (glyph != null) ...[
              Glyph(glyph, size: 36, color: s.onSurface),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (title != c.name) row('Оригинал', c.name),
        row('Враг, уровень', '${levelOfChallenge(c.challenge)}'),
        row('Здоровье', '${c.hp}'),
        row('Атака', '${attackOf(c)}'),
        row('Значок', glyph == null ? 'по роли' : glyphName(glyph)!),
        row('Без места', 'появится на полке холста'),
        for (final p in problems)
          NoticeBanner(
            p.severity == Severity.error ? Notice.error : Notice.warning,
            p.message,
          ),
      ],
    );
  }
}
