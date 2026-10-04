// Прибор «у каждого поля формы есть справка»: обходит все формы; поле ввода без «?»
// или «?» без текста — красный. Заодно: каждый текст из help_texts.dart где-то показан.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/help/help.dart';
import 'package:rpg_builder/help/help_texts.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key), skipOffstage: false).first;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
}

/// Всё, во что автор что-то вводит или что выбирает.
final inputs = find.byWidgetPredicate(
  (w) =>
      w is TextField ||
      w is DropdownButtonFormField ||
      w is ChoiceChip ||
      w is RangeSlider ||
      (w is OutlinedButton && w.key == const Key('sketch-attach')),
);

/// Ключи текстов, шторку которых прибор открыл и прочитал.
final shown = <String>{};

/// Проверяет открытую форму: у каждого поля — «?», каждый «?» открывает свой текст.
Future<void> checkForm(WidgetTester t, String form) async {
  final bare = [
    for (final e in inputs.evaluate())
      if (find
          .ancestor(
            of: find.byWidget(e.widget),
            matching: find.byType(HelpField),
          )
          .evaluate()
          .isEmpty)
        '${e.widget.runtimeType} ${e.widget.key ?? ''}',
  ];
  expect(bare, isEmpty, reason: '$form: поля без справки — ${bare.join(', ')}');

  // Ключ справки — от этого поля, а не от соседнего: подпись поля равна названию в шторке.
  // У объекта области подпись меняется с видом области («Локация», «Квест», «Персонаж»).
  final wrong = <String>[];
  for (final e in find.byType(InputDecorator).evaluate()) {
    final label = (e.widget as InputDecorator).decoration.labelText;
    final id = e.findAncestorWidgetOfExactType<HelpField>()?.id;
    if (label == null || id == null || id == 'assistant.scope.object') continue;
    if (fieldHelp[id]?.title != label) wrong.add('«$label» ← $id');
  }
  expect(wrong, isEmpty, reason: '$form: чужой текст — ${wrong.join(', ')}');

  // Зона «?» не накрывает соседние кнопки («убрать», «добавить», чипы): их центр свободен.
  final zones = [
    for (final e in find.byType(InkResponse).evaluate())
      if ('${e.widget.key}'.contains('help-'))
        t.getRect(find.byWidget(e.widget)),
  ];
  final covered = [
    for (final e in find.bySubtype<ButtonStyleButton>().evaluate())
      if (zones.any((z) => z.contains(t.getCenter(find.byWidget(e.widget)))))
        '${e.widget.runtimeType} ${e.widget.key ?? ''}',
    for (final e in find.byType(ChoiceChip).evaluate())
      if (zones.any((z) => z.contains(t.getCenter(find.byWidget(e.widget)))))
        'ChoiceChip ${e.widget.key ?? ''}',
    for (final e in find.byType(IconButton).evaluate())
      if (zones.any((z) => z.contains(t.getCenter(find.byWidget(e.widget)))))
        'IconButton ${(e.widget as IconButton).tooltip}',
  ];
  expect(covered, isEmpty, reason: '$form: «?» накрыл кнопку — $covered');

  final marks = find.byType(HelpField);
  expect(marks, findsWidgets, reason: '$form: ни одного «?»');
  for (final id in {for (final m in t.widgetList<HelpField>(marks)) m.id}) {
    // Зона нажатия — не меньше 48 dp у каждого «?» этой формы.
    for (final e
        in find.byKey(Key('help-$id'), skipOffstage: false).evaluate()) {
      final size = e.size!;
      expect(
        size.width >= 48 && size.height >= 48,
        isTrue,
        reason: '$form · $id: зона «?» $size меньше 48 dp',
      );
    }
    await tapKey(t, 'help-$id');
    // Нажатие на «?» не ставит курсор в поле под ним.
    expect(
      find.byWidgetPredicate((w) => w is EditableText && w.focusNode.hasFocus),
      findsNothing,
      reason: '$form · $id: «?» поставил курсор в поле',
    );
    final h = fieldHelp[id]!;
    for (final text in [h.title, h.what, h.example]) {
      expect(
        find.descendant(
          of: find.byKey(const Key('help-sheet')),
          matching: find.text(text),
        ),
        findsOneWidget,
        reason: '$form · $id',
      );
    }
    await t.tapAt(const Offset(20, 40));
    await t.pumpAndSettle();
    shown.add(id);
  }
}

void main() {
  testWidgets('все формы: у каждого поля «?» с текстом', (t) async {
    // Высокий экран: форма целиком построена, ленивый список ничего не прячет.
    t.view.physicalSize = const Size(400, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final a = FakeAssistant(List.generate(3, (_) => proposal(floodPlan())));
    final content = await minesContent();
    final ambush = await addAmbush(content, minesId);
    await pumpApp(t, content: content, assistant: a);
    await signUp(t, 'a@test.dev');
    await tapKey(t, 'new-world');
    await checkForm(t, 'новый мир');
    // «?» у «Уровни» не закрывает правый бегунок: его по-прежнему можно тянуть.
    final slider = t.getRect(find.byType(RangeSlider));
    expect(find.text('Уровни: 1–10'), findsOneWidget);
    await t.dragFrom(
      Offset(slider.right - 24, slider.center.dy),
      const Offset(-120, 0),
    );
    await t.pumpAndSettle();
    expect(
      find.text('Уровни: 1–10'),
      findsNothing,
      reason: 'правый бегунок уровней не тянется — его закрыл «?»',
    );
    await t.enterText(find.byKey(const Key('world-title')), 'Пепельные копи');
    await tapKey(t, 'world-save');
    await openWorld(t, 'Пепельные копи');

    // Правка: поля, которые видны только у существующего объекта (добыча, шаги, награды,
    // враги и предметы события).
    for (final slug in ['shtolnya_3', 'klyuch', 'slizen', 'obval', ambush.slug]) {
      await tapKey(t, 'open-$slug');
      await tapKey(t, 'object-edit');
      await checkForm(t, 'правка $slug');
      await back(t);
      await back(t);
    }

    await tapKey(t, 'new-location');
    await checkForm(t, 'новое место');
    await back(t);

    await tapKey(t, 'new-item');
    await checkForm(t, 'новый предмет: оружие');
    await tapKey(t, 'item-kind-armor');
    await checkForm(t, 'новый предмет: броня');
    await back(t);

    await tapKey(t, 'new-character');
    await tapKey(t, 'character-role-enemy');
    await tapKey(t, 'loot-add');
    await checkForm(t, 'новый враг с добычей');
    await back(t);

    await tapKey(t, 'new-event');
    await tapKey(t, 'event-enemy-add');
    await tapKey(t, 'event-item-add');
    await checkForm(t, 'новое событие с врагом и предметом');
    await back(t);

    await tapKey(t, 'new-quest');
    await tapKey(t, 'step-add');
    await tapKey(t, 'reward-add');
    await checkForm(t, 'новый квест с шагом и наградой');
    await back(t);

    await tapKey(t, 'assistant-open');
    await checkForm(t, 'просьба ассистенту');

    // Текст, который нигде не показан, — мёртвый: либо поле убрали, либо ключ с опечаткой.
    expect(
      fieldHelp.keys.toSet().difference(shown),
      isEmpty,
      reason: 'тексты без поля',
    );
  });
}
