// Холст мира (5е): полоса после жеста — что сделано, «проверено · в истории» и «Отменить»
// на 5 секунд (полоска убывает). Предупреждение — жёлтая, ошибка — красная с причиной.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/theme.dart';
import 'gesture_path.dart';

/// Что показать в полосе. [action] — «Отменить» / «Понятно»; null — без кнопки.
class SnackData {
  const SnackData({
    required this.title,
    this.sub = 'проверено · в истории',
    this.tone = GestureTone.ok,
    this.action,
    this.onAction,
    this.seconds = 5,
  });

  final String title;
  final String? sub;
  final GestureTone tone;
  final String? action;
  final VoidCallback? onAction;
  final int seconds;
}

class HolstSnack extends StatelessWidget {
  const HolstSnack({super.key, required this.data});

  final SnackData data;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final (bg, edge, icBg, icFg, icon) = switch (data.tone) {
      GestureTone.ok => (
        s.surfaceContainerHighest,
        s.outline,
        Colors.transparent,
        s.onSurfaceVariant,
        Symbols.check_rounded,
      ),
      GestureTone.warn => (
        s.surfaceContainerHighest,
        c.warn,
        c.warn,
        s.surfaceContainerLowest,
        Symbols.warning_rounded,
      ),
      GestureTone.error => (
        s.errorContainer,
        s.error,
        s.error,
        s.surfaceContainerLowest,
        Symbols.error_rounded,
      ),
    };
    return Material(
      key: const Key('holst-snack'),
      color: bg,
      shape: Border.all(color: edge),
      child: Stack(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 40,
                  color: icBg,
                  child: Icon(icon, color: icFg, fill: 1, size: 22),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data.title,
                          key: const Key('holst-snack-title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (data.sub case final sub?)
                          Text(
                            sub,
                            key: const Key('holst-snack-sub'),
                            style: TextStyle(
                              fontSize: 12,
                              color: data.tone == GestureTone.error
                                  ? s.onErrorContainer
                                  : s.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (data.action case final a?)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: s.outline)),
                    ),
                    child: TextButton(
                      key: const Key('holst-snack-action'),
                      onPressed: data.onAction,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 56),
                        foregroundColor: s.onSurface,
                      ),
                      child: Text(a),
                    ),
                  ),
              ],
            ),
          ),
          // Убывающая полоска: сколько ещё можно отменить.
          if (data.action != null && data.tone != GestureTone.error)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 1, end: 0),
                duration: Duration(seconds: data.seconds),
                builder: (_, v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    child: Container(height: 3, color: s.onSurface),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
