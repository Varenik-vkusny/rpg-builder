// Справка «?»: у поля формы и в шапке экрана — шторка с текстом из help_texts.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/help/help_texts.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key)).first;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Форма правки Слизня — врага с добычей.
Future<void> openEnemyForm(WidgetTester t) async {
  await t.scrollUntilVisible(
    find.byKey(const Key('open-slizen')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tapKey(t, 'open-slizen');
  await tapKey(t, 'object-edit');
}

/// Текст внутри открытой шторки справки.
Finder inSheet(String text) => find.descendant(
  of: find.byKey(const Key('help-sheet')),
  matching: find.text(text),
);

void main() {
  testWidgets('форма врага: «?» у «Шанс» — шторка с фразой и примером', (
    t,
  ) async {
    await pumpApp(t, content: await minesContent());
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await openEnemyForm(t);
    expect(find.byKey(const Key('help-sheet')), findsNothing);

    await tapKey(t, 'help-loot.chance');
    final h = fieldHelp['loot.chance']!;
    expect(inSheet(h.title), findsOneWidget);
    expect(inSheet(h.what), findsOneWidget);
    expect(inSheet(h.example), findsOneWidget);

    // Шторка закрывается, поле под ней — прежнее: «?» ничего не меняет в форме.
    await t.tapAt(const Offset(20, 40));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('help-sheet')), findsNothing);
    expect(find.byKey(const Key('loot-chance-0')), findsOneWidget);
  });

  testWidgets('у каждого поля формы персонажа свой «?» со своим текстом', (
    t,
  ) async {
    await pumpApp(t, content: await minesContent());
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await openEnemyForm(t);
    for (final id in [
      'character.title',
      'character.description',
      'character.role',
      'character.location',
      'character.level',
      'character.hp',
      'character.attack',
      'loot.item',
      'loot.chance',
    ]) {
      await tapKey(t, 'help-$id');
      expect(inSheet(fieldHelp[id]!.what), findsOneWidget, reason: id);
      await t.tapAt(const Offset(20, 40));
      await t.pumpAndSettle();
    }
  });

  testWidgets(
    'план: «?» в шапке появляется с планом — шторка с тремя строками',
    (t) async {
      await openAssistant(t);
      expect(find.byKey(const Key('help-screen-plan')), findsNothing);
      await ask(t);
      await tapKey(t, 'help-screen-plan');
      for (final line in screenHelp['plan']!.lines) {
        expect(inSheet(line), findsOneWidget);
      }
      await t.tapAt(const Offset(20, 40));
      await t.pumpAndSettle();

      await tapKey(t, 'plan-review');
      await tapKey(t, 'help-screen-plan');
      expect(inSheet(screenHelp['plan']!.lines.first), findsOneWidget);
    },
  );
}
