// Прибор «русский поиск в справочнике» (5д, решение владельца 23.10 — словарь в приложении):
// «скелет» находится по словарю, в Open5e уходят ключи найденного; находки — по-русски
// с оригиналом рядом; в мир объект приходит под русским именем, slug и карточка — от оригинала.
// Слова нет в словаре — «Ничего не нашлось», справочник не спрашиваем.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/open5e/ru_names.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'open5e_enemy_test.dart' show creature;
import 'open5e_test.dart' show FakeOpen5e, openLibrary, warPick;

Finder k(String key) => find.byKey(Key(key));

Future<void> search(WidgetTester t, String query) async {
  await t.enterText(k('open5e-query'), query);
  await tapButton(t, 'open5e-search');
}

Future<void> enemies(WidgetTester t) async {
  await t.tap(find.text('Враги'));
  await t.pumpAndSettle();
}

void main() {
  test(
    'словарь: каждое название по-русски; скелет и боевая кирка на месте',
    () {
      final j = jsonDecode(
        File(RuNames.asset).readAsStringSync(),
      ) as Map<String, dynamic>;
      final creatures = (j['creatures'] as Map).cast<String, String>();
      final items = (j['items'] as Map).cast<String, String>();
      // SRD 5.1 + 5.2: 656 существ, 440 обычных и 1259 магических предметов (23.10.2026).
      expect(creatures.length, greaterThanOrEqualTo(650));
      expect(items.length, greaterThanOrEqualTo(1690));
      final latin = [
        for (final e in {...creatures, ...items}.entries)
          if (!RegExp('[а-яё]', caseSensitive: false).hasMatch(e.value)) e.key,
      ];
      expect(latin, isEmpty, reason: 'без перевода');
      expect(creatures['srd_skeleton'], 'Скелет');
      expect(items['srd-2024_war-pick'], 'Боевая кирка');
    },
  );

  test(
    'поиск по словарю: без регистра и «ё»; начинающиеся с запроса — первыми',
    () {
      const names = RuNames(
        creatures: {
          'a': 'Огненный скелет',
          'b': 'Скелет',
          'c': 'Скелет минотавра',
          'd': 'Ёж',
        },
        items: {},
      );
      expect(names.match('СКЕЛЕТ', creatures: true), ['b', 'c', 'a']);
      expect(names.match('еж', creatures: true), ['d']);
      expect(names.match('скелет', creatures: false), isEmpty);
      expect(names.match('скелет', creatures: true, limit: 1), ['b']);
    },
  );

  testWidgets(
    '«скелет» → ключ srd_skeleton → «Скелет» с оригиналом → в мире «Скелет», slug skeleton',
    (t) async {
      final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
      final content = await openLibrary(t, api);
      await enemies(t);
      await search(t, 'скелет');
      expect(api.keysAsked.last, contains('srd_skeleton'));
      final tile = k('open5e-srd_skeleton');
      expect(
        find.descendant(of: tile, matching: find.text('Скелет')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.textContaining('Skeleton')),
        findsOneWidget,
        reason: 'оригинал виден рядом с переводом',
      );

      await tapButton(t, 'open5e-srd_skeleton');
      final preview = k('open5e-enemy-preview');
      for (final s in ['Скелет', 'Оригинал', 'Skeleton']) {
        expect(
          find.descendant(of: preview, matching: find.text(s)),
          findsOneWidget,
          reason: s,
        );
      }
      await tapButton(t, 'open5e-import');
      final e = (await content.snapshotOf(minesId)).characters
          .singleWhere((c) => c.slug == 'skeleton');
      expect(e.title, 'Скелет');
      expect(e.origin!.card['name'], 'Skeleton');
    },
  );

  testWidgets(
    'предмет: «кирка» → War Pick → в мире «Боевая кирка», slug war_pick',
    (t) async {
      final api = FakeOpen5e([warPick()]);
      final content = await openLibrary(t, api);
      await search(t, 'кирка');
      expect(api.keysAsked.last, contains('srd-2024_war-pick'));
      expect(find.text('Боевая кирка'), findsOneWidget);
      await tapButton(t, 'open5e-srd-2024_war-pick');
      await tapButton(t, 'open5e-import');
      final i = (await content.snapshotOf(minesId)).items
          .singleWhere((x) => x.sourceRef == 'srd-2024_war-pick');
      expect((i.title, i.slug), ('Боевая кирка', 'war_pick'));
    },
  );

  testWidgets(
    'слова нет в словаре — «Ничего не нашлось», справочник не спрашивали',
    (t) async {
      final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
      await openLibrary(t, api);
      await enemies(t);
      final asked = api.queries.length;
      await search(t, 'абырвалг');
      expect(k('open5e-empty'), findsOneWidget);
      expect(api.queries.length, asked);
    },
  );

  testWidgets(
    'английский запрос — поиск по названию, находки всё равно по-русски',
    (t) async {
      final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
      await openLibrary(t, api);
      await enemies(t);
      await search(t, 'skeleton');
      expect(api.keysAsked.last, isNull);
      expect(api.queries.last, 'skeleton');
      expect(
        find.descendant(
          of: k('open5e-srd_skeleton'),
          matching: find.text('Скелет'),
        ),
        findsOneWidget,
      );
    },
  );
}
