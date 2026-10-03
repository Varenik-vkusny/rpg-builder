// Прибор «у каждого поля формы есть справка»: обходит все формы; поле ввода без «?»
// или «?» без текста — красный. Заодно: каждый текст из help_texts.dart где-то показан.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/sketch.dart';
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
      w is SketchField,
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

  final marks = find.byType(HelpField);
  expect(marks, findsWidgets, reason: '$form: ни одного «?»');
  for (final id in {for (final m in t.widgetList<HelpField>(marks)) m.id}) {
    await tapKey(t, 'help-$id');
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
    await pumpApp(t, content: await minesContent(), assistant: a);
    await signUp(t, 'a@test.dev');
    await tapKey(t, 'new-world');
    await checkForm(t, 'новый мир');
    await t.enterText(find.byKey(const Key('world-title')), 'Пепельные копи');
    await tapKey(t, 'world-save');
    await openWorld(t, 'Пепельные копи');

    // Правка: поля, которые видны только у существующего объекта (добыча, шаги, награды).
    for (final slug in ['shtolnya_3', 'klyuch', 'slizen', 'obval']) {
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
