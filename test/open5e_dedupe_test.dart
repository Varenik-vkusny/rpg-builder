// Прибор «одно существо — одна строка»: Skeleton есть и в SRD 5.1, и в SRD 5.2 —
// в выдаче один, и это 5.2. Разные существа с похожими именами не склеиваются.
// Английский и русский поиск, враги и предметы; сети нет — тот же фейк API.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';

import 'apply_flow_test.dart' show tapButton;
import 'open5e_test.dart' show FakeOpen5e, openLibrary, potion;

Open5eCreature skeleton(String key, String document) {
  final j = jsonDecode(
    File('test/fixtures/open5e_skeleton.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Open5eCreature.fromJson({
    ...j,
    'key': key,
    'document': {'name': document},
  });
}

final skel51 = skeleton('srd_skeleton', 'System Reference Document 5.1');
final skel52 = skeleton('srd-2024_skeleton', 'System Reference Document 5.2');
final fireSkel = skeleton('srd_fire-skeleton', 'System Reference Document 5.1');
final thirdParty = skeleton('a5e-ag_skeleton', 'Adventurer Guide');

const potion52 = Open5eItem(
  key: 'srd-2024_potion-of-healing',
  name: 'Potion of Healing',
  category: 'potion',
  rarity: 'common',
  cost: 50,
  document: 'System Reference Document 5.2',
);
const greater = Open5eItem(
  key: 'srd_potion-of-greater-healing',
  name: 'Potion of Greater Healing',
  category: 'potion',
  rarity: 'uncommon',
  cost: 100,
  document: 'System Reference Document 5.1',
);

Finder k(String key) => find.byKey(Key(key));

Future<void> search(WidgetTester t, String q) async {
  await t.enterText(k('open5e-query'), q);
  await tapButton(t, 'open5e-search');
}

Future<void> enemies(WidgetTester t) async {
  await t.tap(find.text('Враги'));
  await t.pumpAndSettle();
}

void main() {
  for (final q in ['skeleton', 'скелет']) {
    testWidgets('враги, «$q»: Skeleton из 5.1 и 5.2 — одна строка, свежая', (
      t,
    ) async {
      // 5.1 первым — как отдаёт сервер; остаётся 5.2.
      final api = FakeOpen5e(
        const [],
        creatures: [skel51, fireSkel, skel52, thirdParty],
      );
      await openLibrary(t, api);
      await enemies(t);
      await search(t, q);
      expect(k('open5e-srd-2024_skeleton'), findsOneWidget);
      expect(k('open5e-srd_skeleton'), findsNothing);
      // Разное по сути — не склеено: огненный скелет и книга другого автора.
      if (q == 'skeleton') {
        expect(k('open5e-a5e-ag_skeleton'), findsOneWidget);
        expect(k('open5e-srd_fire-skeleton'), findsOneWidget);
      }
    });
  }

  testWidgets(
    'враги: порядок не важен — 5.2 первым, 5.1 вторым, всё равно 5.2',
    (t) async {
      await openLibrary(t, FakeOpen5e(const [], creatures: [skel52, skel51]));
      await enemies(t);
      await search(t, 'skeleton');
      expect(k('open5e-srd-2024_skeleton'), findsOneWidget);
      expect(k('open5e-srd_skeleton'), findsNothing);
    },
  );

  for (final q in ['potion', 'зелье']) {
    testWidgets('предметы, «$q»: зелье из 5.1 и 5.2 — одна строка, свежая', (
      t,
    ) async {
      await openLibrary(t, FakeOpen5e([potion, greater, potion52]));
      await search(t, q);
      expect(k('open5e-srd-2024_potion-of-healing'), findsOneWidget);
      expect(k('open5e-srd_potion-of-healing'), findsNothing);
      // «Лечение» и «Большое лечение» — разные предметы.
      if (q == 'potion') {
        expect(k('open5e-srd_potion-of-greater-healing'), findsOneWidget);
      }
    });
  }
}
