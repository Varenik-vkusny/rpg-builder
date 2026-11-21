// Прибор «на экране до 20 находок после склейки»: лимит справочника считается не по
// сырой выдаче, а по тому, что осталось после склейки двойников SRD 5.1 / 5.2.
// Фейк API отдаёт не больше запрошенного (как сервер) — старый порядок «20 до склейки»
// на парах изданий оставляет 10 находок, и тест краснеет. Сети нет.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';

import 'open5e_dedupe_test.dart' show enemies, search, skeleton;
import 'open5e_test.dart' show FakeOpen5e, openLibrary, potion;

/// Находки на экране: плитки справочника по ключу образца (`open5e-srd…`).
List<String> tiles() => [
  for (final e in find.byWidgetPredicate((w) {
    final key = w.key;
    return key is ValueKey<String> && key.value.startsWith('open5e-srd');
  }).evaluate())
    (e.widget.key! as ValueKey<String>).value.substring('open5e-'.length),
];

void expectTwentyWithoutTwins(List<String> shown) {
  expect(shown, hasLength(20));
  expect(shown.toSet(), hasLength(20));
  for (final key in shown) {
    if (key.startsWith('srd_')) {
      expect(
        shown,
        isNot(contains('srd-2024_${key.substring(4)}')),
        reason: 'двойник $key остался рядом с 5.2',
      );
    }
  }
}

Future<void> tall(WidgetTester t) async {
  t.view.physicalSize = const Size(800, 6000);
  await t.pumpAndSettle();
}

Map<String, String> dictPart(String part) {
  final j = jsonDecode(
    File('assets/open5e_ru.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (j[part] as Map).cast<String, String>();
}

/// 30 пар «5.1 + 5.2» подряд, как отдаёт сервер: 60 записей.
List<Open5eItem> itemPairs() => [
  for (var i = 0; i < 30; i++)
    for (final p in ['srd', 'srd-2024'])
      Open5eItem(
        key: '${p}_potion-$i',
        name: 'Potion $i',
        category: 'potion',
        document: p == 'srd' ? 'SRD 5.1' : 'SRD 5.2',
      ),
];

/// Все существа из словаря с «дракон» в названии, пары 5.1 + 5.2 подряд.
List<Open5eCreature> dragons() {
  final names = dictPart('creatures');
  return [
    for (final e in names.entries)
      if (e.key.startsWith('srd_') && e.value.toLowerCase().contains('дракон'))
        for (final p in ['srd', 'srd-2024'])
          if (names.containsKey('${p}_${e.key.substring(4)}'))
            skeleton(
              '${p}_${e.key.substring(4)}',
              p == 'srd' ? 'SRD 5.1' : 'SRD 5.2',
            ),
  ];
}

/// Все зелья из словаря, пары 5.1 + 5.2 подряд.
List<Open5eItem> potions() {
  final names = dictPart('items');
  return [
    for (final e in names.entries)
      if (e.key.startsWith('srd_') && e.value.toLowerCase().contains('зелье'))
        for (final p in ['srd', 'srd-2024'])
          if (names.containsKey('${p}_${e.key.substring(4)}'))
            Open5eItem(
              key: '${p}_${e.key.substring(4)}',
              name: e.value,
              category: 'potion',
              document: 'SRD',
            ),
  ];
}

void main() {
  testWidgets(
    'предметы, «potion»: 60 записей в парах → ровно 20, без двойников',
    (t) async {
      final api = FakeOpen5e(itemPairs());
      await openLibrary(t, api);
      await search(t, 'potion');
      await tall(t);
      expectTwentyWithoutTwins(tiles());
      // Порядок выдачи прежний: первые 20 пар, 5.2 на месте 5.1.
      expect(tiles().first, 'srd-2024_potion-0');
      expect(tiles().last, 'srd-2024_potion-19');
      expect(
        api.limitsAsked.last,
        greaterThan(20),
        reason: 'просили с запасом',
      );
    },
  );

  testWidgets('предметы: одиночка и пары вперемешку — не больше 20', (t) async {
    final api = FakeOpen5e([potion, ...itemPairs()]);
    await openLibrary(t, api);
    await search(t, 'potion');
    await tall(t);
    expect(tiles(), hasLength(20));
  });

  testWidgets(
    'враги, «skeleton»: 60 записей в парах → ровно 20, без двойников',
    (t) async {
      final api = FakeOpen5e(
        const [],
        creatures: [
          for (var i = 0; i < 30; i++)
            for (final p in ['srd', 'srd-2024'])
              skeleton('${p}_skeleton-$i', p == 'srd' ? 'SRD 5.1' : 'SRD 5.2'),
        ],
      );
      await openLibrary(t, api);
      await enemies(t);
      await search(t, 'skeleton');
      await tall(t);
      expectTwentyWithoutTwins(tiles());
      expect(tiles().first, 'srd-2024_skeleton-0');
      expect(api.limitsAsked.last, greaterThan(20));
    },
  );

  testWidgets('враги, «дракон» по-русски: ключи словаря с запасом → ровно 20', (
    t,
  ) async {
    final api = FakeOpen5e(const [], creatures: dragons());
    await openLibrary(t, api);
    await enemies(t);
    await search(t, 'дракон');
    await tall(t);
    expect(api.keysAsked.last, hasLength(greaterThan(20)));
    expectTwentyWithoutTwins(tiles());
  });

  testWidgets('предметы, «зелье» по-русски: ключи с запасом → ровно 20', (
    t,
  ) async {
    final api = FakeOpen5e(potions());
    await openLibrary(t, api);
    await search(t, 'зелье');
    await tall(t);
    expect(api.keysAsked.last, hasLength(greaterThan(20)));
    expectTwentyWithoutTwins(tiles());
  });

  testWidgets('русский поиск: порядок — по словарю, не по ответу справочника', (
    t,
  ) async {
    final served = dragons();
    await openLibrary(t, FakeOpen5e(const [], creatures: served));
    await enemies(t);
    await search(t, 'дракон');
    await tall(t);
    final straight = tiles();
    // Справочник вернул те же находки в обратном порядке — на экране то же самое.
    served.setAll(0, served.reversed.toList());
    await search(t, 'дракон');
    await tall(t);
    expect(straight, hasLength(20));
    expect(tiles(), straight);
  });
}
