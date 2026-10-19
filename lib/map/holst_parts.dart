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
import 'token_frame.dart';

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

/// Жетон объекта: значок в квадрате цвета места, число «×3» на значке, имя в две строки.
class TokenTile extends StatelessWidget {
  const TokenTile({
    super.key,
    required this.token,
    required this.hue,
    this.selected = false,
    this.mark = Mark.none,
    this.warn = false,
    this.lifted = false,
    this.target = false,
    this.onWarn,
    this.width = 148,
  });

  final HolstToken token;

  /// Цвет места; на полке — нейтральный.
  final Color? hue;
  final bool selected;
  final Mark mark;

  /// Жёлтая метка предупреждения в углу.
  final bool warn;

  /// Поднят пальцем — светлее и с обводкой.
  final bool lifted;

  /// Сюда тянут нить — пунктирная обводка.
  final bool target;

  /// Нажали на жёлтую метку — окно с причиной и «Откатить».
  final VoidCallback? onWarn;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final markColor = switch (mark) {
      Mark.isNew => c.ok,
      Mark.changed => c.change,
      Mark.none => null,
    };
    final icBg = switch (mark) {
      Mark.isNew => c.okContainer,
      Mark.changed => Color.alphaBlend(
        c.change.withValues(alpha: .3),
        s.surfaceContainer,
      ),
      Mark.none =>
        hue == null
            ? s.surfaceContainerHighest
            : Color.alphaBlend(hue!.withValues(alpha: .34), s.surfaceContainer),
    };
    final t = token;
    final tile = Container(
      width: width,
      height: tokenSize.height,
      decoration: BoxDecoration(
        color: lifted ? s.surfaceContainerHighest : s.surfaceContainerHigh,
        border: markColor == null
            ? null
            : Border.all(color: markColor, width: 2),
      ),
      child: Row(
        mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            width: 40,
            color: icBg,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                framedGlyph(
                  t,
                  s.onSurfaceVariant,
                  s.onSurface,
                  key: Key('frame-${t.slug}'),
                ),
                if (t.count case final n?)
                  // В рамке значок 36 × 36: число садится на её нижний край.
                  Positioned(
                    right: frameOf(t.kind) == null ? -9 : -6,
                    bottom: frameOf(t.kind) == null ? -12 : -1,
                    child: Container(
                      color: s.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      child: Text(
                        '×$n',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: width == null ? FlexFit.loose : FlexFit.tight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                t.title,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final ring = selected || lifted || target;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: tokenTextScaleMax,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          if (ring)
            Positioned(
              left: -4,
              top: -4,
              right: -4,
              bottom: -4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: s.onSurface,
                      width: 2,
                      // Пунктира у рамки во Flutter нет: цель нити — тоньше.
                      strokeAlign: target ? BorderSide.strokeAlignInside : 0,
                    ),
                  ),
                ),
              ),
            ),
          if (warn)
            // Метка 22 × 22 в углу, зона касания — 40 × 40 вокруг неё.
            Positioned(
              top: -9,
              right: -9,
              child: GestureDetector(
                key: Key('warn-${t.slug}'),
                behavior: HitTestBehavior.opaque,
                onTap: onWarn,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 22,
                      height: 22,
                      color: c.warn,
                      child: Icon(
                        Symbols.warning_rounded,
                        size: 16,
                        fill: 1,
                        color: s.surfaceContainerLowest,
                      ),
                    ),
                  ),
                ),
              ),
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
