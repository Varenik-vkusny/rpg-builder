// Обзор мира (4.2): счётчики по видам, сводка проверки, последние изменения.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'check_flow_test.dart' show expectStrip;
import 'manual_edit_flow_test.dart' show openMines;

void main() {
  testWidgets('обзор мира: счётчики, сводка проверки, последние изменения', (
    t,
  ) async {
    final content = await openMines(t);
    expectCounts({'locations': 2, 'items': 2, 'characters': 2, 'quests': 1});
    expectStrip(t, 'overview-check', errors: 0, warnings: 0);
    // Вид А: пустую историю не показываем вовсе.
    expect(find.byKey(const Key('overview-recent')), findsNothing);
    expect(find.text('Изменений пока не было'), findsNothing);

    // Удалили рынок вручную — счётчик и последние изменения обновились.
    await tapButton(t, 'open-rynok');
    await tapButton(t, 'object-edit');
    await tapButton(t, 'object-delete');
    await tapButton(t, 'confirm-yes');
    expectCounts({'locations': 1, 'items': 2, 'characters': 2, 'quests': 1});
    // Мини-ряд той же формы, что в истории: имя и глагол, без «Применён».
    for (final text in ['Рынок', 'Удалено']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('overview-recent')),
          matching: find.text(text),
        ),
        findsOneWidget,
        reason: text,
      );
    }
    expect(find.textContaining('Применён'), findsNothing);
    expect(content.journal, hasLength(1));

    await tapButton(t, 'overview-history');
    expect(find.text('История изменений'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await tapButton(t, 'overview-check');
    expect(find.text('Проверка мира'), findsOneWidget);
  });
}

/// Счётчики обзора мира: у плитки вида [kind] видно число.
void expectCounts(Map<String, int> counts) {
  for (final MapEntry(key: kind, value: n) in counts.entries) {
    expect(
      find.descendant(
        of: find.byKey(Key('count-$kind')),
        matching: find.text('$n'),
      ),
      findsOneWidget,
      reason: '$kind: $n',
    );
  }
}
