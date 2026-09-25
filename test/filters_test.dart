// Фильтры списков мира (4.3): предметы по редкости и виду, персонажи по роли.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/filters.dart';
import 'package:rpg_builder/content/item.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'manual_edit_flow_test.dart' show openMines;

void main() {
  test('фильтр: пусто — все; редкость и вид вместе; роль', () async {
    final w = await (await minesContent()).snapshot(minesId);
    String items(ContentFilter f) =>
        f.items(w.items).map((i) => i.slug).join(',');
    String chars(ContentFilter f) =>
        f.characters(w.characters).map((c) => c.slug).join(',');

    expect(items(const ContentFilter()), 'klyuch,kirka');
    expect(items(const ContentFilter(rarities: {Rarity.rare})), 'kirka');
    expect(
      items(const ContentFilter(rarities: {Rarity.rare, Rarity.common})),
      'klyuch,kirka',
    );
    expect(
      items(
        const ContentFilter(rarities: {Rarity.rare}, kinds: {ItemKind.quest}),
      ),
      '',
    );
    expect(items(const ContentFilter(kinds: {ItemKind.quest})), 'klyuch');
    expect(chars(const ContentFilter(roles: {Role.enemy})), 'slizen');
    expect(chars(const ContentFilter(roles: {Role.npc})), 'brigadir');
    expect(chars(const ContentFilter()), 'brigadir,slizen');
    expect(ContentFilter.toggle({Role.npc}, Role.npc), <Role>{});
    expect(ContentFilter.toggle(<Role>{}, Role.npc), {Role.npc});
  });

  testWidgets('фильтр: на экране мира — редкий предмет, враги', (t) async {
    await openMines(t);
    expect(find.byKey(const Key('open-klyuch')), findsOneWidget);
    expect(find.byKey(const Key('filter-rarity-rare')), findsNothing);
    await tapButton(t, 'filter-items');
    await tapButton(t, 'filter-rarity-rare');
    expect(find.text('Фильтр: 1'), findsOneWidget);
    expect(find.byKey(const Key('open-klyuch')), findsNothing);
    expect(find.byKey(const Key('open-kirka')), findsOneWidget);
    await tapButton(t, 'filter-rarity-rare');
    expect(find.byKey(const Key('open-klyuch')), findsOneWidget);

    await tapButton(t, 'filter-kind-quest');
    expect(find.byKey(const Key('open-kirka')), findsNothing);
    expect(find.byKey(const Key('open-klyuch')), findsOneWidget);

    await tapButton(t, 'filter-characters');
    await tapButton(t, 'filter-role-enemy');
    expect(find.byKey(const Key('open-brigadir')), findsNothing);
    expect(find.byKey(const Key('open-slizen')), findsOneWidget);
  });
}
