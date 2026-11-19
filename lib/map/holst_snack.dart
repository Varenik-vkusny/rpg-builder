// Холст мира (5е): полоса после жеста — что сделано и «Отменить»
// на 5 секунд (полоска убывает). Предупреждение — жёлтая, ошибка — красная с причиной.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/theme.dart';
import 'gesture_path.dart';

/// Новая связь в полосе — рисунком: значок и имя первого конца, стрелка с числом или
/// словом связи, значок и имя второго (владелец 19.11: «рисовать, а не писать текстом»).
typedef SnackLink = ({
  IconData? fromIcon,
  String from,
  String what,
  IconData? toIcon,
  String to,
});

/// Что показать в полосе. [action] — «Отменить» / «Понятно»; null — без кнопки.
/// [link] — вместо заголовка рисуется связь; [title] остаётся подписью для озвучки.
class SnackData {
  const SnackData({
    required this.title,
    this.sub,
    this.link,
    this.tone = GestureTone.ok,
    this.action,
    this.onAction,
    this.seconds = 5,
  });

  final String title;
  final String? sub;
  final SnackLink? link;
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
                // У связи галочки нет: рисунок связи и есть «сделано»; место — под имена.
                if (data.link == null || data.tone != GestureTone.ok)
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
                        if (data.link case final l?)
                          Semantics(
                            label: data.title,
                            child: ExcludeSemantics(child: _LinkStrip(l)),
                          )
                        else
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

/// Связь рисунком: [значок] Слизень ──40%──▶ [значок] Кирка. Имена режутся с краю,
/// стрелка с числом не сжимается.
class _LinkStrip extends StatelessWidget {
  const _LinkStrip(this.link);

  final SnackLink link;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final ok = AppColors.of(context).ok;
    final pillStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: s.surfaceContainerLowest,
    );
    // Значки и стрелка не сжимаются; уступают имена (режутся многоточием), а на совсем
    // узком экране их нет вовсе — остаётся рисунок «значок ─40%─▶ значок». Ширину
    // считаем от экрана: в полосе стоит IntrinsicHeight, LayoutBuilder там нельзя.
    final pill = (TextPainter(
      text: TextSpan(text: link.what, style: pillStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout()).width;
    // Поля полосы, «Отменить», два значка, усы стрелки и наконечник.
    const around = 16 + 26 + 104 + 56 + 44;
    final names = MediaQuery.sizeOf(context).width - around - pill - 10 >= 72;
    Widget box(IconData? icon) => icon == null
        ? const SizedBox.shrink()
        : Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(border: Border.all(color: s.outline)),
            child: Icon(icon, size: 16),
          );
    // Место делится по длине имён: короткое не держит половину впустую («Нов…» при «Кирка»).
    Widget name(String text, String key) => Flexible(
      flex: text.characters.length.clamp(1, 40),
      child: Text(
        text,
        key: Key(key),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
    return Row(
      key: const Key('holst-snack-link'),
      children: [
        box(link.fromIcon),
        if (names) name(link.from, 'holst-snack-from'),
        // Последний запас: если и без имён тесно (крупный шрифт телефона), подпись на
        // стрелке режется многоточием, а не ломает полосу.
        Flexible(
          flex: names ? 0 : 1,
          fit: FlexFit.loose,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 2, color: ok),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    color: ok,
                    child: Text(
                      link.what,
                      key: const Key('holst-snack-what'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pillStyle,
                    ),
                  ),
                ),
                Container(width: 6, height: 2, color: ok),
                Icon(Symbols.play_arrow_rounded, size: 14, color: ok, fill: 1),
              ],
            ),
          ),
        ),
        box(link.toIcon),
        if (names) name(link.to, 'holst-snack-to'),
      ],
    );
  }
}
