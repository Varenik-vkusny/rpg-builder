// Блок места на карте-холсте (5а.3) в стиле «Телетекст на графите»: рамка цвета места,
// жители, вложенные числом, значок проблемы. Вид «рамка-план» — выбор владельца 01.10, подтверждён 02.10.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../content/location.dart';
import '../ui/cover_card.dart';
import '../ui/theme.dart';
import 'map_model.dart';

class PlaceBlock extends StatelessWidget {
  const PlaceBlock({
    super.key,
    required this.place,
    required this.stats,
    required this.onTap,
    required this.onEnter,
  });

  final Location place;
  final PlaceStats stats;
  final VoidCallback onTap;

  /// «Войти» — холст уровнем ниже (5а.5).
  final VoidCallback onEnter;

  /// Для озвучки и тестов: «Копи, жителей 3, внутри 1, событий 1, событий внутри 2, ошибка: 1».
  String get label => [
    place.title,
    'жителей ${stats.residents}',
    if (stats.inner > 0) 'внутри ${stats.inner}',
    if (stats.events + stats.eventsInside > 0) 'событий ${stats.events}',
    if (stats.eventsInside > 0) 'событий внутри ${stats.eventsInside}',
    if (stats.worst case final w?)
      '${w.label.toLowerCase()}: ${stats.problems}',
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final hues = AppColors.of(context).coverHues;
    final hue = hues[CoverCard.colorIndex(place.slug, hues.length)];
    // Блок — одна кнопка со сводкой; кнопка входа внутри — своя, со своей подписью (TalkBack).
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: SizedBox.fromSize(
        size: blockSize,
        child: _Pressable(
          onTap: onTap,
          // Блок — фиксированного размера на холсте: крупный шрифт телефона растёт в нём
          // только до предела, иначе название в две строки выдавливает счётчики за рамку.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: blockTextScaleMax,
            child: _Frame(place, stats, hue, onEnter),
          ),
        ),
      ),
    );
  }
}

/// Отклик на касание: блок чуть проседает под пальцем и отдаёт лёгкий щелчок.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _set(true),
    onTapCancel: () => _set(false),
    onTapUp: (_) => _set(false),
    onTap: () {
      HapticFeedback.selectionClick();
      widget.onTap();
    },
    child: AnimatedScale(
      scale: _down ? .94 : 1,
      duration: Duration(milliseconds: _down ? 70 : 220),
      curve: _down ? Curves.easeOut : Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _down ? .85 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    ),
  );
}

/// Уровни места: «ур. 2–4».
class _Levels extends StatelessWidget {
  const _Levels(this.place);
  final Location place;

  @override
  Widget build(BuildContext context) => Text(
    'ур. ${place.levelMin}–${place.levelMax}',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12,
    ),
  );
}

/// Число со значком: «👥 3».
class _Count extends StatelessWidget {
  const _Count(this.icon, this.n, this.color, {this.plus = 0});
  final IconData icon;
  final int n;
  final Color color;

  /// Сколько ещё у мест внутри: «⚡ 1 +2».
  final int plus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: [
      Icon(icon, size: 16, color: color),
      Text(
        plus > 0 ? '$n +$plus' : '$n',
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

/// Значок проблемы: ошибка — красная ячейка с «!», предупреждение — жёлтая с треугольником.
class _ProblemCell extends StatelessWidget {
  const _ProblemCell(this.stats);
  final PlaceStats stats;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final error = stats.worst == Severity.error;
    final bg = error ? s.error : AppColors.of(context).warn;
    final fg = error ? s.onError : s.surface;
    return Container(
      key: const Key('problem-cell'),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      color: bg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Icon(
            error ? Symbols.error_rounded : Symbols.warning_rounded,
            size: 16,
            color: fg,
            fill: 1,
          ),
          Text(
            '${stats.problems}',
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Рамка-план: тёмная ячейка с крупным приглушённым значком; если внутри есть
/// места, позади видны рамки «этажей» — сразу ясно, что в место можно войти.
class _Frame extends StatelessWidget {
  const _Frame(this.place, this.stats, this.hue, this.onEnter);
  final Location place;
  final PlaceStats stats;
  final Color hue;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final layers = stats.inner.clamp(0, 2);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = layers; i >= 1; i--)
          Positioned.fill(
            left: 6.0 * i,
            top: -6.0 * i,
            right: -6.0 * i,
            bottom: 6.0 * i,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: s.surface,
                border: Border.all(
                  color: hue.withValues(alpha: i == 1 ? .6 : .3),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: s.surfaceContainerLow,
              border: Border.all(color: hue, width: 1.5),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _EnterCell(
                    key: Key('enter-${place.slug}'),
                    title: place.title,
                    hue: hue,
                    full: stats.inner > 0,
                    onTap: onEnter,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(width: 14, height: 3, color: hue),
                ),
                ExcludeSemantics(
                  child: Padding(
                    // Справа место под ячейку проблемы — название под неё не заходит.
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      stats.worst == null ? 10 : 48,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: s.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _Levels(place),
                        const Spacer(),
                        // Счётчики не заходят под ячейку «войти» (48 dp справа):
                        // три счётчика разом сжимаются, а не вылезают.
                        SizedBox(
                          width: blockSize.width - 12 - 48 - 4,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              spacing: 12,
                              children: [
                                _Count(
                                  Symbols.groups_rounded,
                                  stats.residents,
                                  s.onSurface,
                                ),
                                if (stats.inner > 0)
                                  _Count(
                                    Symbols.stacks_rounded,
                                    stats.inner,
                                    hue,
                                  ),
                                // ⚡ — свои события места, «+N» — события мест внутри.
                                if (stats.events + stats.eventsInside > 0)
                                  _Count(
                                    Symbols.bolt_rounded,
                                    stats.events,
                                    s.onSurface,
                                    plus: stats.eventsInside,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (stats.worst != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: ExcludeSemantics(child: _ProblemCell(stats)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Кнопка «войти» в углу блока: зона нажатия 48×48. Внутри есть места — ячейка залита цветом
/// места, приглашает; пусто — только рамка (войти можно, там подсказка).
class _EnterCell extends StatelessWidget {
  const _EnterCell({
    super.key,
    required this.title,
    required this.hue,
    required this.full,
    required this.onTap,
  });
  final String title;
  final Color hue;
  final bool full;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Войти в «$title»',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox.square(
          dimension: 48,
          child: Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: full ? hue : Colors.transparent,
                border: Border.all(color: hue, width: 1.5),
              ),
              child: Icon(
                Symbols.south_east_rounded,
                size: 20,
                color: full ? s.surface : hue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
