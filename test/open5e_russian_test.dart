// Прибор «русский поиск в справочнике» (5д): «скелет» ищется как «skeleton», находки — по-русски
// с оригиналом рядом; в мир объект приходит под русским именем, slug и карточка — от оригинала.
// Перевод недоступен — английский поиск работает, автору сказано почему; русский — просьба писать
// по-английски, справочник не дёргается.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'open5e_enemy_test.dart' show creature;
import 'open5e_test.dart' show FakeOpen5e, openLibrary, warPick;

Finder k(String key) => find.byKey(Key(key));

Future<void> search(WidgetTester t, String query) async {
  await t.enterText(k('open5e-query'), query);
  await tapButton(t, 'open5e-search');
}

void main() {
  testWidgets(
    '«скелет» → ищем skeleton → «Скелет» с оригиналом → в мире «Скелет», slug skeleton',
    (t) async {
      final api = FakeOpen5e(
        const [],
        creatures: [creature('skeleton')],
        words: {'skeleton': 'скелет', 'Skeleton': 'Скелет'},
      );
      final content = await openLibrary(t, api);
      await t.tap(find.text('Враги'));
      await t.pumpAndSettle();
      await search(t, 'скелет');
      expect(api.queries.last, 'skeleton');
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
      expect(k('open5e-untranslated'), findsNothing);

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
      final api = FakeOpen5e(
        [warPick()],
        words: {'pick': 'кирка', 'War Pick': 'Боевая кирка'},
      );
      final content = await openLibrary(t, api);
      await search(t, 'кирка');
      expect(api.queries.last, 'pick');
      expect(find.text('Боевая кирка'), findsOneWidget);
      await tapButton(t, 'open5e-srd-2024_war-pick');
      await tapButton(t, 'open5e-import');
      final i = (await content.snapshotOf(minesId)).items
          .singleWhere((x) => x.sourceRef == 'srd-2024_war-pick');
      expect((i.title, i.slug), ('Боевая кирка', 'war_pick'));
    },
  );

  testWidgets(
    'перевод недоступен: английский ищется с пометкой, русский — просьба писать по-английски',
    (t) async {
      final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
      await openLibrary(t, api);
      await t.tap(find.text('Враги'));
      await t.pumpAndSettle();
      await search(t, 'skeleton');
      expect(
        find.descendant(
          of: k('open5e-srd_skeleton'),
          matching: find.text('Skeleton'),
        ),
        findsOneWidget,
      );
      expect(k('open5e-untranslated'), findsOneWidget);

      final asked = api.queries.length;
      await search(t, 'скелет');
      expect(
        find.text('Перевод недоступен — напиши название по-английски'),
        findsOneWidget,
      );
      expect(
        api.queries.length,
        asked,
        reason: 'справочник не спрашивали кириллицей',
      );
    },
  );

  testWidgets('английский запрос не переводится — переводятся только находки', (
    t,
  ) async {
    final api = FakeOpen5e(
      const [],
      creatures: [creature('skeleton')],
      words: {'Skeleton': 'Скелет'},
    );
    await openLibrary(t, api);
    await t.tap(find.text('Враги'));
    await t.pumpAndSettle();
    await search(t, 'skeleton');
    expect(api.translated.where((x) => x.$2 == 'en'), isEmpty);
    expect(api.translated.last.$1, ['Skeleton']);
    expect(api.translated.last.$2, 'ru');
  });
}
