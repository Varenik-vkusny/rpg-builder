// Жетон объекта на холсте (вынесен из holst_parts.dart 21.11 — резка ниже 400 строк).
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/theme.dart';
import 'holst_parts.dart';
import 'holst_scene.dart';
import 'token_frame.dart';
import 'token_name.dart';

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
    this.handle,
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

  /// Ручка связи на правом краю («Строить»): от неё тянут нить, остальное — листает.
  final Widget? handle;

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
              padding: EdgeInsets.only(right: handle == null ? 8 : 4),
              child: TokenName(
                t.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
            ),
          ),
          if (handle != null) const SizedBox(width: threadHandleWidth),
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
          // Ручка — в нижней части правого края: верхний угол занят меткой ⚠
          // (ревью 22.11: метка закрывала кружок, нить не тянулась).
          if (handle case final h?)
            Positioned(right: 0, top: threadHandleTop, bottom: 0, child: h),
          if (warn)
            // Метка 22 × 22 в углу, зона касания — 40 × 40 вокруг неё;
            // в «Строить» — 28 × 28, чтобы не наезжать на ручку.
            Positioned(
              top: -9,
              right: -9,
              child: GestureDetector(
                key: Key('warn-${t.slug}'),
                behavior: HitTestBehavior.opaque,
                onTap: onWarn,
                child: SizedBox(
                  width: handle == null ? 40 : 28,
                  height: handle == null ? 40 : 28,
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

/// Ширина зоны ручки связи: кружок 28 dp и по 2 dp воздуха.
const threadHandleWidth = 32.0;

/// Ручка начинается ниже угловой метки ⚠ (её зона в «Строить» кончается на 19 dp).
const threadHandleTop = 20.0;

/// Ручка связи: кружок на правом краю жетона, виден только в «Строить». Нить тянут от
/// неё; провести по остальному жетону — листать холст.
class ThreadHandle extends StatelessWidget {
  const ThreadHandle({
    super.key,
    required this.color,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Цвет места (на полке — нейтральный).
  final Color color;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: onStart,
      onPanUpdate: onUpdate,
      onPanEnd: (_) => onEnd(),
      onPanCancel: onCancel,
      child: SizedBox(
        width: threadHandleWidth,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(
                color.withValues(alpha: .34),
                s.surfaceContainer,
              ),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
