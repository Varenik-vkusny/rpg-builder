// Холст мира (5е), вид «плашка» (выбор владельца 16.10): место — цветная шапка цвета места
// и заливка; объект — жетон 148 × 48, значок в квадрате цвета места, «×3» на значке,
// имя в две строки без многоточия. Выбор — белая обводка; голубой — только главные действия.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../content/location.dart';
import '../ui/cover_card.dart';
import '../ui/theme.dart';
import 'holst_scene.dart';

export 'token_tile.dart';

/// Текст в жетоне растёт с шрифтом телефона только до предела: жетон фиксированного размера.
const tokenTextScaleMax = 1.15;

/// Цвет места — тот же, что у его обложки в списках.
Color placeHue(BuildContext context, Location l) {
  final hues = AppColors.of(context).coverHues;
  return hues[CoverCard.colorIndex(l.slug, hues.length)];
}

IconData tokenIcon(HolstToken t) => switch (t.kind) {
  TokenKind.enemy => Symbols.skull_rounded,
  TokenKind.npc => Symbols.person_rounded,
  TokenKind.event => Symbols.bolt_rounded,
  TokenKind.quest => Symbols.flag_rounded,
  TokenKind.item => switch (t.sub) {
    'weapon' => Symbols.swords_rounded,
    'armor' => Symbols.shield_rounded,
    'consumable' => Symbols.science_rounded,
    'quest' => Symbols.key_rounded,
    _ => Symbols.deployed_code_rounded,
  },
};

String kindName(TokenKind k) => switch (k) {
  TokenKind.enemy => 'враг',
  TokenKind.npc => 'житель',
  TokenKind.event => 'событие',
  TokenKind.item => 'предмет',
  TokenKind.quest => 'квест',
};

/// Подсветка объекта: новое — зелёная рамка, изменено — пурпурная.
enum Mark { none, isNew, changed }

/// Плашка места: шапка цвета места (имя и уровни), заливка тем же цветом, приглушённая.
/// Издалека вместо жетонов — крупные числа.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.far,
    required this.stats,
    required this.problems,
    this.mark = Mark.none,
    this.drop = false,
  });

  final HolstPlace place;
  final bool far;
  final FarStats stats;
  final int problems;
  final Mark mark;

  /// Сюда сейчас бросят объект — пунктирная обводка.
  final bool drop;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final hue = switch (mark) {
      Mark.isNew => c.ok,
      Mark.changed => c.change,
      Mark.none => placeHue(context, place.place),
    };
    final l = place.place;
    final ink = s.surfaceContainerLowest;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(hue.withValues(alpha: .13), s.surface),
        border: drop ? Border.all(color: s.onSurface, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: hue,
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    l.title,
                    maxLines: far ? 2 : 1,
                    overflow: TextOverflow.fade,
                    softWrap: far,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      fontSize: far ? 20 : 14,
                    ),
                  ),
                ),
                if (!far) ...[
                  const SizedBox(width: 8),
                  Text(
                    'ур. ${l.levelMin}–${l.levelMax}',
                    style: TextStyle(
                      color: ink.withValues(alpha: .75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (far) _FarNumbers(stats, problems),
        ],
      ),
    );
  }
}

class _FarNumbers extends StatelessWidget {
  const _FarNumbers(this.n, this.problems);

  final FarStats n;
  final int problems;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    Widget num(IconData icon, int v, {bool fill = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26, color: s.onSurfaceVariant, fill: fill ? 1 : 0),
        const SizedBox(width: 3),
        Text(
          '$v',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ],
    );
    final empty =
        n.residents + n.enemies + n.events + n.inner == 0 && problems == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (n.residents > 0) num(Symbols.person_rounded, n.residents),
          if (n.enemies > 0) num(Symbols.skull_rounded, n.enemies),
          if (n.events > 0) num(Symbols.bolt_rounded, n.events, fill: true),
          if (n.inner > 0) num(Symbols.south_east_rounded, n.inner),
          if (problems > 0)
            Container(
              key: const Key('far-problems'),
              color: c.warn,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.warning_rounded,
                    size: 24,
                    fill: 1,
                    color: s.surfaceContainerLowest,
                  ),
                  Text(
                    '$problems',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: s.surfaceContainerLowest,
                    ),
                  ),
                ],
              ),
            ),
          if (empty)
            Text(
              'пусто',
              style: TextStyle(fontSize: 18, color: s.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// Сколько проблем у места: само место и всё, что в нём стоит.
int placeProblems(List<Problem> problems, HolstPlace p) {
  final ids = {p.place.id, for (final t in p.tokens) t.id};
  return problems.where((x) => ids.contains(x.objectId)).length;
}
