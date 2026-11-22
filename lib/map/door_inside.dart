// Холст мира (5е): подпись двери «внутри: …» — столько имён целиком, сколько влезает,
// остальное «· ещё N». Не обрывается на запятой и не режет имя посередине (телефон 22.11).
import 'package:flutter/material.dart';

/// Строк под подпись: на двери 104 dp высоты три строки по 12 влезают вместе с шапкой.
const _lines = 3;

/// Подпись из [names] (непустой список): самая полная, которую [fits] принимает.
/// «внутри: Слизень, Засада», «внутри: Слизень · ещё 1», в крайнем случае «внутри: ещё 2».
String insideLabel(List<String> names, bool Function(String) fits) {
  final n = names.length;
  for (var k = n; k >= 1; k--) {
    final text =
        'внутри: ${names.take(k).join(', ')}${k < n ? ' · ещё ${n - k}' : ''}';
    if (fits(text)) return text;
  }
  return 'внутри: ещё $n';
}

/// Подпись двери: места под неё — три строки ширины [maxWidth]; [names] не пуст.
class DoorInside extends StatelessWidget {
  const DoorInside({super.key, required this.names, required this.style});

  final List<String> names;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // Меряем тем же стилем, каким Text рисует: шрифт — из темы, а не по умолчанию.
    final full = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, box) {
        TextPainter paint(String s, {int? lines}) => TextPainter(
          text: TextSpan(text: s, style: full),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: lines,
        )..layout(maxWidth: lines == null ? double.infinity : box.maxWidth);
        bool fits(String s) {
          // Каждое слово — целиком в строке (длинное слово иначе рвётся по буквам),
          // весь текст — в три строки (две строки на двери 148 dp мало: «внутри:» занимает первую).
          final words = s.split(' ').where((w) => w.isNotEmpty);
          if (words.any((w) => paint(w).width > box.maxWidth)) return false;
          return !paint(s, lines: _lines).didExceedMaxLines;
        }

        return Text(
          insideLabel(names, fits),
          maxLines: _lines,
          overflow: TextOverflow.clip,
          style: style,
        );
      },
    );
  }
}
