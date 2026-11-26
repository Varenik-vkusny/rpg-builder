// Раскрытый набор в истории — коротко: строка на объект, «Откатить» первой строкой.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/manual_create.dart';
import 'package:rpg_builder/content/manual_save.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart' show minesId;
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
    // Вид А: операция — ячейка цвета действия и имя. Создание — без полей.
    expect(find.text('Утопленник'), findsOneWidget);
    expect(find.textContaining('здоровье'), findsNothing);
    expect(find.text('добыча Слизень → Ключ'), findsOneWidget);
    // Изменение — имя и поле, ниже «было → стало».
    expect(find.textContaining('Штольня №3 описание'), findsOneWidget);
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

  // Владелец 25.11: под «Откатить» не повторять заголовок — ни «Создано вручную: Причал»
  // в кавычках, ни строкой «новое: Причал». Просьба автора и операции, которые говорят
  // больше заголовка, остаются.
  testWidgets('история: раскрытый набор не повторяет заголовок', (t) async {
    final content = await flooded(t);
    await createManually(
      content,
      minesId,
      (w) => createLocationEdit(
        minesId,
        w,
        const NewLocation(
          title: 'Причал',
          description: '',
          levelMin: 1,
          levelMax: 3,
        ),
      ),
    );
    await openHistory(t);
    // Вид А: в голове — имя «Причал» и «Создано»; раскрытый набор его не повторяет.
    await t.tap(find.text('Причал'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('revert-set-1')), findsOneWidget);
    expect(find.text('«Создано вручную: Причал»'), findsNothing);
    expect(find.text('Причал'), findsOneWidget, reason: 'имя только в голове');
    // Набор ассистента: просьба автора не равна заголовку — видна, операции видны.
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    expect(find.textContaining('«затопи её'), findsOneWidget);
    expect(find.text('Утопленник'), findsOneWidget);
  });

  // Владелец 26.11: «Откатить» была прижата к голове набора и сжата.
  testWidgets(
    'история: «Откатить» во всю ширину, 52 dp, с отступом от головы',
    (t) async {
      await flooded(t);
      await openHistory(t);
      await t.tap(find.text(flood));
      await t.pumpAndSettle();
      final button = t.getRect(find.byKey(const Key('revert-set-0')));
      final head = t.getRect(find.byKey(const Key('history-head-set-0')));
      expect(button.height, greaterThanOrEqualTo(52));
      expect(button.top - head.bottom, greaterThanOrEqualTo(10));
    },
  );
}
