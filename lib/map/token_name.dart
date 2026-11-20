// Имя под значком жетона: переносится только между словами и после дефиса, а слово,
// которое не влезает в ширину, ужимается по шрифту, а в самом мелком — обрезается многоточием.
import 'package:flutter/material.dart';

/// Неразрывный дефис (U+2011) движок не переносит — заменяем на обычный, после него можно рвать.
String breakableName(String s) => s.replaceAll('‑', '-');

/// Куски, внутри которых рвать нельзя: слова, дефис остаётся в конце своего куска.
List<String> nameUnits(String s) => [
  for (final w in s.split(RegExp(r'\s+')))
    if (w.isNotEmpty) ...RegExp(r'[^-]+-?|-').allMatches(w).map((m) => m[0]!),
];

class TokenName extends StatelessWidget {
  const TokenName(
    this.title, {
    super.key,
    required this.style,
    this.minSize = 10,
  });

  final String title;
  final TextStyle style;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    final text = breakableName(title);
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    return LayoutBuilder(
      builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final dir = Directionality.of(context);
        final base = style.fontSize ?? 14;
        double unitMax(double size) {
          var m = 0.0;
          for (final u in nameUnits(text)) {
            final p = TextPainter(
              text: TextSpan(
                text: u,
                style: style.copyWith(fontSize: size),
              ),
              textDirection: dir,
              textScaler: scaler,
            )..layout();
            if (p.width > m) m = p.width;
          }
          return m;
        }

        var size = base;
        var fits = !box.maxWidth.isFinite;
        while (!fits && size >= minSize) {
          fits = unitMax(size) <= box.maxWidth;
          if (!fits) size -= 1;
        }
        return Text(
          text,
          // Не влезло даже в самом мелком — одна строка с многоточием, без разрыва слова.
          maxLines: fits ? 2 : 1,
          softWrap: true,
          overflow: fits ? TextOverflow.clip : TextOverflow.ellipsis,
          style: style.copyWith(fontSize: fits ? size : minSize),
        );
      },
    );
  }
}
