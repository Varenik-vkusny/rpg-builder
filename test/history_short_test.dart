// Раскрытый набор в истории — коротко: строка на объект, «Откатить» первой строкой.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'history_flow_test.dart' show flood, flooded, openHistory;

void main() {
  testWidgets('история: набор раскрыт — по строке на объект, без простыни', (
    t,
  ) async {
    await flooded(t);
    await openHistory(t);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    // Простыни нет: ни «БЫЛО / СТАЛО», ни «Изменить · Локация».
    expect(find.text('БЫЛО'), findsNothing);
    expect(find.text('СТАЛО'), findsNothing);
    expect(find.textContaining('Изменить ·'), findsNothing);
    // Создание — одной строкой, без полей.
    expect(find.text('новое: utoplennik'), findsOneWidget);
    expect(find.textContaining('здоровье'), findsNothing);
    expect(find.text('убрано: добыча slizen/klyuch'), findsOneWidget);
    // Изменение — одной строкой «поле было → стало».
    expect(find.textContaining('shtolnya_3: описание'), findsOneWidget);
    expect(find.textContaining('затоплена по пояс'), findsOneWidget);
  });

  testWidgets('история: «Откатить» выше первой операции набора', (t) async {
    await flooded(t);
    await openHistory(t);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    final button = t.getTopLeft(find.byKey(const Key('revert-set-0'))).dy;
    final firstOp = t
        .getTopLeft(find.byKey(const Key('history-op-utoplennik')))
        .dy;
    expect(button, lessThan(firstOp));
    await tapButton(t, 'revert-set-0');
    expect(find.byKey(const Key('confirm-yes')), findsOneWidget);
  });
}
