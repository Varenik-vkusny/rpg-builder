// Вопрос перед удалением объекта и перед откатом набора: без «да» мир не меняется.
// Спрашивать о невозможном незачем: объект со ссылками и откат с конфликтом отклоняются
// сразу, без вопроса.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/item.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'history_flow_test.dart' show flood, flooded, openHistory;
import 'manual_edit_flow_test.dart' show open, openMines;

final _question = find.byKey(const Key('confirm'));

void main() {
  testWidgets('удаление: вопрос с названием; «Отмена» — объект на месте, форма '
      'открыта', (t) async {
    final content = await openMines(t);
    await open(t, 'rynok');
    await tapButton(t, 'object-delete');
    expect(_question, findsOneWidget);
    expect(find.text('Удалить «Рынок»?'), findsOneWidget);
    expect(find.textContaining('можно откатить'), findsOneWidget);

    await tapButton(t, 'confirm-no');
    expect(_question, findsNothing);
    expect(find.text('Изменить локацию'), findsOneWidget);
    expect(
      (await content.locations(minesId)).map((l) => l.slug),
      contains('rynok'),
    );
    expect(content.journal, isEmpty);
  });

  testWidgets('удаление: «Удалить» — объекта нет, запись в истории', (t) async {
    final content = await openMines(t);
    await open(t, 'rynok');
    await tapButton(t, 'object-delete');
    await tapButton(t, 'confirm-yes');
    expect(find.text('Изменить локацию'), findsNothing);
    expect(
      (await content.locations(minesId)).map((l) => l.slug),
      isNot(contains('rynok')),
    );
    expect(content.journal.single.entry.request, 'Удаление вручную: Рынок');
  });

  testWidgets(
    'удаление предмета без ссылок: вопрос; «Удалить» — предмета нет',
    (t) async {
      final content = await openMines(t);
      await content.createItem(
        minesId,
        const NewItem(
          title: 'Фонарь',
          kind: ItemKind.misc,
          rarity: Rarity.common,
          level: 1,
          price: 1,
        ),
      );
      await t.pageBack();
      await t.pumpAndSettle();
      await openWorld(t, 'Пепельные копи');
      await open(t, 'fonar');
      await tapButton(t, 'object-delete');
      expect(find.text('Удалить «Фонарь»?'), findsOneWidget);
      expect(
        (await content.items(minesId)).map((i) => i.slug),
        contains('fonar'),
      );
      await tapButton(t, 'confirm-yes');
      expect(
        (await content.items(minesId)).map((i) => i.slug),
        isNot(contains('fonar')),
      );
    },
  );

  testWidgets('удаление объекта со ссылками: вопроса нет, сразу причина', (
    t,
  ) async {
    final content = await openMines(t);
    await open(t, 'klyuch');
    await tapButton(t, 'object-delete');
    expect(_question, findsNothing);
    expect(find.textContaining('Нельзя удалить «Ключ»'), findsOneWidget);
    expect(content.journal, isEmpty);
  });

  testWidgets('откат: вопрос; «Отмена» — набор не откачен; «Откатить» — '
      'откачен', (t) async {
    final content = await flooded(t);
    await openHistory(t);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();

    await tapButton(t, 'revert-set-0');
    expect(_question, findsOneWidget);
    expect(find.text('Откатить набор?'), findsOneWidget);
    await tapButton(t, 'confirm-no');
    expect(find.textContaining('Откачен'), findsNothing);
    expect(
      (await content.characters(minesId)).map((c) => c.slug),
      contains('utoplennik'),
    );
    // Кнопка снова доступна: отказ не оставил экран «занятым».
    await tapButton(t, 'revert-set-0');
    await tapButton(t, 'confirm-yes');
    expect(find.textContaining('Откачен'), findsOneWidget);
    expect(
      (await content.characters(minesId)).map((c) => c.slug),
      isNot(contains('utoplennik')),
    );
  });

  testWidgets('откат с конфликтом: вопроса нет, сразу причина', (t) async {
    final content = await flooded(t);
    content.version++; // автор поправил мир после набора
    await openHistory(t);
    await t.tap(find.text(flood));
    await t.pumpAndSettle();
    await tapButton(t, 'revert-set-0');
    expect(_question, findsNothing);
    expect(find.byKey(const Key('revert-conflicts-set-0')), findsOneWidget);
  });
}
