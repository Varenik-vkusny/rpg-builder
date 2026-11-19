// Полоса после жеста связи — связь рисунком (владелец 19.11): значок, имя, стрелка с числом
// или словом, значок, имя. На узком телефоне не переполняется: имена режутся, стрелка — нет.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rpg_builder/map/holst_snack.dart';
import 'package:rpg_builder/ui/theme.dart';

Future<void> pumpSnack(WidgetTester t, SnackData d, double width) async {
  // Экран целиком такой ширины: полоса считает место от ширины экрана.
  t.view
    ..physicalSize = Size(width, 400)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: appTheme(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: HolstSnack(data: d),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final (what, from, to) in [
    ('убить ×12', 'Скрипящий гоблин‑страж', 'Ключи от лебёдки'),
    ('поговорить', 'Обвал в старой штольне', 'Бригадир Пепельных копей'),
    ('40%', 'Слизень', 'Кирка'),
  ]) {
    testWidgets('связь «$what» на 320 dp: значки и стрелка целиком, без переполнения', (
      t,
    ) async {
      await pumpSnack(
        t,
        SnackData(
          title: 'Связь: $from — $what — $to',
          link: (
            fromIcon: Symbols.skull_rounded,
            from: from,
            what: what,
            toIcon: Symbols.key_rounded,
            to: to,
          ),
          action: 'Отменить',
          onAction: () {},
        ),
        320,
      );
      expect(t.takeException(), isNull);
      final strip = find.byKey(const Key('holst-snack-link'));
      // Число или слово связи — целиком; оба значка и стрелка на месте.
      expect(
        t.widget<Text>(find.byKey(const Key('holst-snack-what'))).data,
        what,
      );
      final icons = [
        for (final e in find
            .descendant(of: strip, matching: find.byType(Icon))
            .evaluate())
          (e.widget as Icon).icon,
      ];
      expect(icons, [
        Symbols.skull_rounded,
        Symbols.play_arrow_rounded,
        Symbols.key_rounded,
      ]);
      expect(find.text('Отменить'), findsOneWidget);
      expect(find.textContaining('Связь:'), findsNothing);
    });
  }

  testWidgets('на обычном телефоне (412 dp) — и имена обоих концов', (t) async {
    await pumpSnack(
      t,
      SnackData(
        title: 'Связь: Слизень — роняет 40% — Кирка',
        link: (
          fromIcon: Symbols.skull_rounded,
          from: 'Слизень',
          what: '40%',
          toIcon: Symbols.key_rounded,
          to: 'Кирка',
        ),
        action: 'Отменить',
        onAction: () {},
      ),
      412,
    );
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('holst-snack-from')), findsOneWidget);
    expect(find.byKey(const Key('holst-snack-to')), findsOneWidget);
  });
}
