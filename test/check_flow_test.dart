// Экран «Проверка мира» без сети: открывается из мира и показывает проблемы.
// Сами правила проверяет world_check_test.dart на снимке в памяти.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/check_screen.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/quest.dart';
import 'package:rpg_builder/ui/theme.dart';
import 'package:rpg_builder/worlds/world.dart';

import 'fakes.dart';

/// Подменённая база, в которой лежит квест без выдающего и без шагов —
/// такого настоящая база не пустит, а копия мира с планом ассистента может.
class _BrokenContent extends FakeContent {
  @override
  Future<List<Quest>> quests(String worldId) async => const [
    Quest(
      id: 'quest-0',
      slug: 'pustoy',
      title: 'Пустой квест',
      description: '',
      giverId: null,
      steps: [],
      rewardIds: [],
    ),
  ];
}

/// Итог проверки полосой: числа в ячейках, красная при ошибках, жёлтая при
/// предупреждениях, ноль — без заливки (вид А, срез 3).
void expectStrip(
  WidgetTester t,
  String stripKey, {
  required int errors,
  required int warnings,
}) {
  final theme = Theme.of(t.element(find.byKey(Key(stripKey))));
  for (final (k, n, fill) in [
    ('check-errors', errors, theme.colorScheme.error),
    (
      'check-warnings',
      warnings,
      AppColors.of(t.element(find.byKey(Key(stripKey)))).warn,
    ),
  ]) {
    final cell = find.descendant(
      of: find.byKey(Key(stripKey)),
      matching: find.byKey(Key(k)),
    );
    expect(
      find.descendant(of: cell, matching: find.text('$n')),
      findsOneWidget,
      reason: '$k: число $n',
    );
    final box = t.widget<Container>(
      find.descendant(of: cell, matching: find.byType(Container)).first,
    );
    expect(box.color, n == 0 ? isNull : fill, reason: '$k: заливка');
  }
}

void main() {
  const world = World(
    id: 'w',
    title: 'Пепельные копи',
    setting: '',
    tone: '',
    levelMin: 1,
    levelMax: 10,
  );

  testWidgets('проверка открывается из мира; пустой мир без проблем', (
    t,
  ) async {
    await pumpApp(t);
    await signUp(t, 'a@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await t.tap(find.byKey(const Key('check-world')));
    await t.pumpAndSettle();
    expect(find.text('Проверка мира'), findsOneWidget);
    expectStrip(t, 'check-summary', errors: 0, warnings: 0);
  });

  testWidgets('ошибки квеста видны списком с числом ошибок', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: CheckScreen(
          world: world,
          repo: _BrokenContent(),
          assistant: FakeAssistant(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expectStrip(t, 'check-summary', errors: 2, warnings: 0);
    expect(find.text('«Пустой квест»: у квеста нет выдающего'), findsOneWidget);
    expect(find.text('«Пустой квест»: у квеста нет шагов'), findsOneWidget);
  });

  testWidgets('предупреждение: урон выше потолка видно на экране', (t) async {
    final content = FakeContent();
    await content.createItem(
      world.id,
      const NewItem(
        title: 'Кайло',
        kind: ItemKind.weapon,
        rarity: Rarity.common,
        level: 2,
        damage: 14,
        price: 10,
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: CheckScreen(
          world: world,
          repo: content,
          assistant: FakeAssistant(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expectStrip(t, 'check-summary', errors: 0, warnings: 2);
    expect(
      find.text('«Кайло»: урон 14 выше потолка 8 (ур. 2, обычный)'),
      findsOneWidget,
    );
    expect(
      find.text('«Кайло» нельзя получить: не выпадает и не выдаётся наградой'),
      findsOneWidget,
    );
    expect(find.text('Предупреждение'), findsNWidgets(2));
  });

  testWidgets('предупреждение: атака врага выше потолка видно на экране', (
    t,
  ) async {
    final content = FakeContent();
    await content.createCharacter(
      world.id,
      const NewCharacter(
        title: 'Утопленник',
        description: '',
        role: Role.enemy,
        locationId: null,
        level: 3,
        hp: 30,
        attack: 14,
      ),
    );
    await t.pumpWidget(
      MaterialApp(
        home: CheckScreen(
          world: world,
          repo: content,
          assistant: FakeAssistant(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expectStrip(t, 'check-summary', errors: 0, warnings: 1);
    expect(
      find.text('«Утопленник»: атака 14 выше потолка 10 (ур. 3)'),
      findsOneWidget,
    );
  });
}
