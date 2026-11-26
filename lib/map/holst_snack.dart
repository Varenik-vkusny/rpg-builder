// Холст мира (5е): полоса после жеста — что сделано и «Отменить»
// на 5 секунд (полоска убывает). Предупреждение — рамка warn, ошибка — красная с причиной одной строкой.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/done_strip.dart';
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
    this.kind = DoneKind.info,
    this.action,
    this.onAction,
    this.seconds = 5,
  });

  final String title;
  final String? sub;
  final SnackLink? link;
  final GestureTone tone;
  final DoneKind kind;
  final String? action;
  final VoidCallback? onAction;
  final int seconds;
}

class HolstSnack extends StatelessWidget {
  const HolstSnack({super.key, required this.data});

  final SnackData data;

  /// Вид ячейки: тон жеста сильнее вида — отказ красный, предупреждение с рамкой.
  DoneKind get _kind => switch (data.tone) {
    GestureTone.error => DoneKind.error,
    GestureTone.warn => DoneKind.warn,
    GestureTone.ok => data.kind,
  };

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final link = data.link;
    return DoneStrip(
      key: const Key('holst-snack'),
      kind: _kind,
      title: link == null ? data.title : null,
      titleKey: const Key('holst-snack-title'),
      sub: data.sub,
      subKey: const Key('holst-snack-sub'),
      body: link == null
          ? null
          : Semantics(
              label: data.title,
              child: ExcludeSemantics(child: _LinkStrip(link)),
            ),
      action: data.action == null ? null : _action(s),
      // Убывающая полоска: сколько ещё можно отменить.
      bottom: data.action != null && data.tone != GestureTone.error
          ? _timer(s)
          : null,
    );
  }

  Widget _action(ColorScheme s) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(left: BorderSide(color: s.outline)),
    ),
    child: TextButton(
      key: const Key('holst-snack-action'),
      onPressed: data.onAction,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: const RoundedRectangleBorder(),
        foregroundColor: s.onSurface,
      ),
      child: Text(
        data.action!,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );

  Widget _timer(ColorScheme s) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1, end: 0),
    duration: Duration(seconds: data.seconds),
    builder: (_, v, _) => Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: v,
        child: Container(height: 3, color: s.onSurface),
      ),
    ),
  );
}

/// Связь рисунком: значок с именем мелко под ним ─40%─▶ значок с именем. Имена под
/// значками, а не рядом: на телефоне 360 dp рядом им не хватало места («Нов… ─30%─▶ Ки…»).
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
    // Подпись на стрелке не сжимается, пока помещается; на совсем узком экране
    // (крупный шрифт телефона) режется многоточием, а не ломает полосу. Ширину считаем
    // от экрана: в полосе стоит IntrinsicHeight, LayoutBuilder там нельзя.
    final pill = (TextPainter(
      text: TextSpan(text: link.what, style: pillStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout()).width;
    // Поля полосы, «Отменить», два значка, усы стрелки и наконечник.
    const around = 16 + 26 + 104 + 48 + 48;
    final roomy = MediaQuery.sizeOf(context).width - around - pill >= 0;
    // Конец связи: значок, под ним имя мелко. Место делится по длине имён.
    Widget end(IconData? icon, String name, String key) => Flexible(
      flex: name.characters.length.clamp(1, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(border: Border.all(color: s.outline)),
            child: icon == null ? null : Icon(icon, size: 16),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            key: Key(key),
            // Две строки: «Новый / враг» читается, «Новый в…» — нет (телефон 19.11).
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
    final arrow = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 2, color: ok),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
    );
    return Row(
      key: const Key('holst-snack-link'),
      children: [
        end(link.fromIcon, link.from, 'holst-snack-from'),
        if (roomy) arrow else Flexible(child: arrow),
        end(link.toIcon, link.to, 'holst-snack-to'),
      ],
    );
  }
}
