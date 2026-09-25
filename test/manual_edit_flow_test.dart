// Правка и удаление вручную на экранах (4.1), подменённая база: тап по объекту →
// заполненная форма → «Сохранить» / «Удалить» → мир перечитан, набор в истории.
// Как правка ложится в базу и откатывается — test/manual_edit_db_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/content/manual_save.dart';
import 'package:rpg_builder/content/quest.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';

Future<FakeContent> openMines(WidgetTester t) async {
  t.view.physicalSize = const Size(800, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final content = await minesContent();
  await pumpApp(t, content: content, assistant: FakeAssistant());
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  return content;
}

Future<void> open(WidgetTester t, String slug) => tapButton(t, 'open-$slug');

void main() {
  testWidgets('правка вручную: локация — форма заполнена, сохранить → мир и '
      'история', (t) async {
    final content = await openMines(t);
    await open(t, 'shtolnya_3');
    expect(find.text('Изменить локацию'), findsOneWidget);
    final description = find.byKey(const Key('location-description'));
    expect(
      t.widget<TextField>(description).controller!.text,
      'обвалившаяся выработка',
    );
    await t.enterText(description, 'затоплена по пояс');
    await tapButton(t, 'location-save');

    expect(find.text('Изменить локацию'), findsNothing);
    final shaft = (await content.locations(minesId))
        .firstWhere((l) => l.slug == 'shtolnya_3');
    expect(shaft.description, 'затоплена по пояс');
    final set = content.journal.single.entry;
    expect(set.request, 'Правка вручную: Штольня №3');
  });

  testWidgets('правка вручную: ничего не поменяли — в историю не пишется', (
    t,
  ) async {
    final content = await openMines(t);
    await open(t, 'rynok');
    await tapButton(t, 'location-save');
    expect(content.journal, isEmpty);
  });

  test(
    'правка вручную: правка ломает мир — не сохранено (правило 4)',
    () async {
      final content = await minesContent();
      final w = await content.snapshotOf(minesId);
      final q = w.quests.single;
      // Квест без шагов — ошибка проверки мира.
      final edit = editQuest(
        minesId,
        q,
        NewQuest(
          title: q.title,
          description: q.description,
          giverId: q.giverId!,
          steps: const [],
          rewardIds: q.rewardIds,
        ),
      );
      final said = await saveManualEdit(content, minesId, w, edit);
      expect(said, startsWith('Правка ломает мир — не сохранено'));
      expect(content.journal, isEmpty);
      expect((await content.quests(minesId)).single.steps, hasLength(3));
    },
  );

  testWidgets('удаление вручную: на ключ ссылаются — нельзя, сказано кто', (
    t,
  ) async {
    final content = await openMines(t);
    await open(t, 'klyuch');
    await tapButton(t, 'object-delete');
    expect(find.textContaining('Нельзя удалить «Ключ»'), findsOneWidget);
    expect(find.textContaining('роняет: «Слизень»'), findsOneWidget);
    expect(find.textContaining('шаг 3 квеста «Обвал»'), findsOneWidget);
    expect(
      (await content.items(minesId)).map((i) => i.slug),
      contains('klyuch'),
    );
    expect(content.journal, isEmpty);
  });

  testWidgets(
    'удаление вручную: квест удалён, в истории — откатить → вернулся',
    (t) async {
      final content = await openMines(t);
      await open(t, 'obval');
      await tapButton(t, 'object-delete');
      expect(find.text('Изменить квест'), findsNothing);
      expect(await content.quests(minesId), isEmpty);
      expect(find.text('Обвал'), findsNothing);

      await tapButton(t, 'history-open');
      expect(find.text('Удаление вручную: Обвал'), findsOneWidget);
      await t.tap(find.text('Удаление вручную: Обвал'));
      await t.pumpAndSettle();
      await tapButton(t, 'revert-set-0');
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Обвал'), findsOneWidget);
    },
  );

  testWidgets('правка вручную: у предмета вид и у персонажа роль не меняются', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'kirka');
    expect(find.text('Изменить предмет'), findsOneWidget);
    final kinds = find.byWidgetPredicate(
      (w) => w is ChoiceChip && w.onSelected == null,
    );
    expect(kinds, findsWidgets);
    await t.pageBack();
    await t.pumpAndSettle();
    await open(t, 'slizen');
    expect(find.text('Изменить персонажа'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is ChoiceChip && w.onSelected == null,
      ),
      findsWidgets,
    );
  });
}
