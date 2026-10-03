// Прибор «у каждого экрана есть справка»: мир, карта, план, история, проверка, экспорт,
// Open5e. Экран без «?» или «?» без текста — красный; текст, который нигде не показан, — тоже.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/help/help.dart';
import 'package:rpg_builder/help/help_texts.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'open5e_test.dart' show FakeOpen5e, potion, warPick;

/// Ключи экранов, шторку которых прибор открыл и прочитал.
final shown = <String>{};

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

/// На открытом экране есть «?» с ключом [id]; шторка показывает все его строки.
Future<void> checkScreen(WidgetTester t, String id) async {
  expect(
    find.byKey(Key('help-screen-$id')),
    findsOneWidget,
    reason: 'экран «$id» без справки',
  );
  final zone = t.getSize(find.byKey(Key('help-screen-$id')));
  expect(
    zone.width >= 48 && zone.height >= 48,
    isTrue,
    reason: 'экран «$id»: зона «?» $zone меньше 48 dp',
  );
  await tapKey(t, 'help-screen-$id');
  final h = screenHelp[id]!;
  for (final text in [h.title, ...h.lines]) {
    expect(
      find.descendant(
        of: find.byKey(const Key('help-sheet')),
        matching: find.text(text),
      ),
      findsOneWidget,
      reason: 'экран «$id»: «$text»',
    );
  }
  await t.tapAt(const Offset(20, 40));
  await t.pumpAndSettle();
  shown.add(id);
}

void main() {
  testWidgets('все экраны: «?» открывает свои строки', (t) async {
    // Мир с ошибкой (житель в несуществующем месте): экспорт показывает своё окно.
    final content = await minesContent();
    await content.createCharacter(
      minesId,
      const NewCharacter(
        title: 'Призрак',
        description: '',
        role: Role.npc,
        locationId: 'loc-нет',
      ),
    );
    final a = FakeAssistant(List.generate(3, (_) => proposal(floodPlan())));
    await pumpApp(
      t,
      content: content,
      assistant: a,
      open5e: FakeOpen5e([warPick(), potion]),
    );
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await checkScreen(t, 'world');
    // На экране мира «?» того же размера, что в формах.
    expect(
      t
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const Key('help-screen-world')),
              matching: find.byType(Icon),
            ),
          )
          .size,
      helpMarkSize,
    );

    await tapKey(t, 'map-open');
    await checkScreen(t, 'map');
    await back(t);

    await tapKey(t, 'history-open');
    await checkScreen(t, 'history');
    await back(t);

    await tapKey(t, 'check-world');
    await checkScreen(t, 'check');
    await back(t);

    await tapKey(t, 'world-export');
    await checkScreen(t, 'export');
    await tapKey(t, 'export-cancel');

    await tapKey(t, 'open5e-open');
    await checkScreen(t, 'open5e');
    await back(t);

    await tapKey(t, 'assistant-open');
    await ask(t);
    await checkScreen(t, 'plan');

    // Текст экрана, который нигде не показан, — мёртвый.
    expect(
      screenHelp.keys.toSet().difference(shown),
      isEmpty,
      reason: 'тексты без экрана',
    );
  });
}
