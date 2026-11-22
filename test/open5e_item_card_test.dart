// Карточка предмета из Open5e — короткая, как у врага: что за предмет и что принесёт
// импорт, без экрана плана («Что изменится», «было → стало», счётчик предупреждений мира).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/ui/parts.dart';

import 'apply_flow_test.dart' show tapButton;
import 'open5e_test.dart' show FakeOpen5e, openLibrary, potion, warPick;

void main() {
  testWidgets('предмет из Open5e: короткая карточка, без экрана плана', (
    t,
  ) async {
    await openLibrary(t, FakeOpen5e([warPick(), potion]));
    await tapButton(t, 'open5e-srd-2024_war-pick');
    final card = find.byKey(const Key('open5e-item-preview'));
    expect(card, findsOneWidget);
    for (final s in ['Боевая кирка', 'Оригинал', 'War Pick', 'Оружие']) {
      expect(
        find.descendant(of: card, matching: find.text(s)),
        findsOneWidget,
        reason: s,
      );
    }
    expect(find.text('Обычный'), findsOneWidget);
    expect(find.text('5 зол.'), findsOneWidget);
    expect(find.text('Урон'), findsOneWidget);
    expect(find.byKey(const Key('open5e-import')), findsOneWidget);
    expect(find.byKey(const Key('open5e-back')), findsOneWidget);
    // Старый экран плана ушёл.
    expect(find.textContaining('Что изменится'), findsNothing);
    expect(find.text('БЫЛО'), findsNothing);
    expect(find.text('СТАЛО'), findsNothing);
    expect(find.textContaining('По одному'), findsNothing);
    expect(find.textContaining('Импорт из Open5e'), findsNothing);
  });

  testWidgets(
    'предмет из Open5e: плашки — только новое от импорта, не весь мир',
    (t) async {
      await openLibrary(t, FakeOpen5e([warPick(), potion]));
      await tapButton(t, 'open5e-srd-2024_war-pick');
      final banners = find.descendant(
        of: find.byKey(const Key('open5e-item-preview')),
        matching: find.byType(NoticeBanner),
      );
      // В мире копей свои предупреждения; новое от импорта — одно: предмет нечем получить.
      expect(banners, findsOneWidget);
      expect(
        find.textContaining('«Боевая кирка» нельзя получить'),
        findsOneWidget,
      );
      expect(find.textContaining('предупрежд'), findsNothing);
    },
  );
}
