// Обзор мира (4.2): счётчики по видам, сводка проверки, последние изменения.
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'manual_edit_flow_test.dart' show openMines;

void main() {
  testWidgets('обзор мира: счётчики, сводка проверки, последние изменения', (
    t,
  ) async {
    final content = await openMines(t);
    expect(
      find.text('Локаций 2 · Предметов 2 · Персонажей 2 · Квестов 1'),
      findsOneWidget,
    );
    expect(find.text('Проблем не найдено'), findsOneWidget);
    expect(find.text('Изменений пока не было'), findsOneWidget);

    // Удалили рынок вручную — счётчик и последние изменения обновились.
    await tapButton(t, 'open-rynok');
    await tapButton(t, 'object-edit');
    await tapButton(t, 'object-delete');
    expect(
      find.text('Локаций 1 · Предметов 2 · Персонажей 2 · Квестов 1'),
      findsOneWidget,
    );
    expect(find.text('Применён: Удаление вручную: Рынок'), findsOneWidget);
    expect(content.journal, hasLength(1));

    await tapButton(t, 'overview-history');
    expect(find.text('История изменений'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await tapButton(t, 'overview-check');
    expect(find.text('Проверка мира'), findsOneWidget);
  });
}
