// Прибор «имя жетона не рвётся посреди слова»: «Гоблин‑страж» не становится «Гоблин‑стр / аж».
// Каждая строка имени, кроме первой, начинается после пробела или дефиса. Настоящие шрифты нужны:
// иначе все буквы одной ширины и разрыв не воспроизводится.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/holst_parts.dart';
import 'package:rpg_builder/map/holst_scene.dart';
import 'package:rpg_builder/ui/theme.dart';

import 'real_fonts.dart';

const names = [
  'Гоблин‑страж',
  'Гоблин-разведчик',
  'Старый бригадир',
  'Кирка',
  'Трёхголовыйкрокодилосаврусище',
  'Старый Трёхголовыйкрокодилосаврусище',
];

HolstToken tok(String title) =>
    HolstToken(id: 'i', slug: 's', kind: TokenKind.npc, title: title);

Future<void> pumpTile(WidgetTester t, String title) => t.pumpWidget(
  MaterialApp(
    theme: appTheme(Brightness.dark),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: TokenTile(token: tok(title), hue: null),
      ),
    ),
  ),
);

/// Начала строк абзаца, кроме первой: индекс, где курсор перескакивает на новую строку.
List<int> lineStarts(RenderParagraph p, String text) {
  final starts = <int>[];
  var y = p.getOffsetForCaret(const TextPosition(offset: 0), Rect.zero).dy;
  for (var i = 1; i < text.length; i++) {
    final dy = p.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
    if (dy > y + 1) starts.add(i);
    y = dy;
  }
  return starts;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFont();
  });

  for (final title in names) {
    testWidgets('«$title» не рвётся посреди слова', (t) async {
      await pumpTile(t, title);
      final text = title.replaceAll('‑', '-');
      final p = t.renderObject<RenderParagraph>(
        find.descendant(of: find.byType(TokenTile), matching: find.text(text)),
      );
      for (final s in lineStarts(p, text)) {
        final prev = text[s - 1];
        expect(
          prev == ' ' || prev == '-',
          isTrue,
          reason: 'строка начинается с середины слова: «${text.substring(s)}»',
        );
      }
      expect(p.size.width, lessThanOrEqualTo(92.1));
    });
  }

  testWidgets('неразрывный дефис заменён обычным', (t) async {
    await pumpTile(t, 'Гоблин‑страж');
    expect(find.text('Гоблин-страж'), findsOneWidget);
  });
}
