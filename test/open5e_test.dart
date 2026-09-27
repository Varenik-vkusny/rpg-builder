// Образцы Open5e (4.6): поиск → план «создать предмет» с атрибуцией → проверка на копии →
// «Импортировать» набором изменений (в историю).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan_preview.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';
import 'package:rpg_builder/open5e/open5e_import.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';

/// Настоящий ответ api.open5e.com/v2/items/srd-2024_war-pick/ (26.09.2026).
Open5eItem warPick() => Open5eItem.fromJson(
  jsonDecode(File('test/fixtures/open5e_war_pick.json').readAsStringSync())
      as Map<String, dynamic>,
);

const potion = Open5eItem(
  key: 'srd_potion-of-healing',
  name: 'Potion of Healing',
  category: 'potion',
  rarity: 'common',
  cost: 50,
  document: 'System Reference Document 5.1',
);

class FakeOpen5e implements Open5eApi {
  FakeOpen5e(this.result);
  final Object result;
  final queries = <String>[];

  @override
  Future<List<Open5eItem>> searchItems(String query) async {
    queries.add(query);
    if (result is Exception) throw result;
    return result as List<Open5eItem>;
  }
}

Future<FakeContent> openLibrary(WidgetTester t, Open5eApi api) async {
  t.view.physicalSize = const Size(800, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final content = await minesContent();
  await pumpApp(t, content: content, open5e: api);
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  await tapButton(t, 'open5e-open');
  await t.enterText(find.byKey(const Key('open5e-query')), 'pick');
  await tapButton(t, 'open5e-search');
  return content;
}

void main() {
  test(
    'образец: ответ Open5e разобран — оружие, кости урона, цена, документ',
    () {
      final o = warPick();
      expect(o.key, 'srd-2024_war-pick');
      expect(o.name, 'War Pick');
      expect(o.damageDice, '1d8');
      expect(o.cost, 5);
      expect(o.document, 'System Reference Document 5.2');
    },
  );

  test(
    'образец → план: предмет с источником, средним уроном и новым slug',
    () async {
      final world = await (await minesContent()).snapshot(minesId);
      final op = importPlan(warPick(), world).ops.single;
      expect(op.slug, 'war_pick');
      expect(op.fields, {
        'title': 'War Pick',
        'kind': 'weapon',
        'rarity': 'common',
        'level': 1,
        'damage': 5,
        'price': 5,
        'source': 'Open5e',
        'source_ref': 'srd-2024_war-pick',
      });
      expect(averageDamage('2d6'), 7);
      expect(kindOf(potion), ItemKind.consumable);
      expect(
        rarityOf(
          const Open5eItem(
            key: 'k',
            name: 'n',
            category: 'c',
            rarity: 'very-rare',
            document: 'd',
          ),
        ),
        Rarity.epic,
      );

      // Второй импорт того же образца — новый slug, а не перезапись.
      final preview = previewPlan(world, importPlan(warPick(), world), null);
      expect(preview.hasErrors, isFalse);
      final again = importPlan(warPick(), preview.copy).ops.single;
      expect(again.slug, 'war_pick_2');
    },
  );

  testWidgets(
    'образец: найти → источник виден → импортировать → предмет в мире и в истории',
    (t) async {
      final api = FakeOpen5e([warPick(), potion]);
      final content = await openLibrary(t, api);
      expect(api.queries, ['pick']);
      await tapButton(t, 'open5e-srd-2024_war-pick');
      expect(
        find.textContaining(
          'Open5e, System Reference Document 5.2 — CC BY 4.0',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('srd-2024_war-pick'),
        findsOneWidget,
        reason: '«было → стало» показывает образец',
      );
      await tapButton(t, 'open5e-import');

      expect(
        find.text('Образцы Open5e'),
        findsNothing,
        reason: 'вернулись в мир',
      );
      await t.scrollUntilVisible(
        find.text('War Pick'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await openObject(t, 'War Pick');
      expect(find.text('Оружие · Обычный'), findsOneWidget);
      expectTile('Уровень', '1');
      expectTile('Урон', '5');
      expectTile('Цена', '5');
      expect(find.text('Образец: Open5e'), findsOneWidget);
      final item = (await content.items(minesId))
          .firstWhere((i) => i.slug == 'war_pick');
      expect(
        (item.source, item.sourceRef, item.damage),
        ('Open5e', 'srd-2024_war-pick', 5),
      );
      final set = content.changeSets.single;
      expect(set.status, 'applied');
      expect(set.draft.request, 'Импорт из Open5e: War Pick');
      expect(set.draft.toParams(minesId)['p_scope_type'], 'import');
      expect(set.draft.toParams(minesId)['p_attempts'], isNull);
    },
  );

  testWidgets(
    'образец: Open5e недоступен — понятная ошибка; ничего не нашлось — так и сказано',
    (t) async {
      await openLibrary(t, FakeOpen5e(const Open5eError('Open5e ответил 503')));
      expect(
        find.text('Open5e недоступен: Open5e ответил 503'),
        findsOneWidget,
      );
    },
  );

  testWidgets('образец: пустой ответ — «Ничего не нашлось»', (t) async {
    final content = await openLibrary(t, FakeOpen5e(const <Open5eItem>[]));
    expect(find.byKey(const Key('open5e-empty')), findsOneWidget);
    expect(content.changeSets, isEmpty);
  });
}
