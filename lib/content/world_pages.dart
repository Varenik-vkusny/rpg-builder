// Страницы объектов мира: локация (кто здесь), персонаж (добыча), предмет, квест (шаги).
// Правка — прежние формы New*Screen по кнопке ✏.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../ui/object_page.dart';
import '../worlds/world.dart';
import 'character.dart';
import 'content_repo.dart';
import 'item.dart';
import 'location.dart';
import 'new_character_screen.dart';
import 'new_item_screen.dart';
import 'new_location_screen.dart';
import 'new_quest_screen.dart';
import 'quest.dart';

IconData characterIcon(Character c) => switch (c.role) {
  Role.enemy => Symbols.skull_rounded,
  Role.merchant => Symbols.storefront_rounded,
  Role.npc => Symbols.person_rounded,
};

IconData itemIcon(Item i) => switch (i.kind) {
  ItemKind.weapon => Symbols.swords_rounded,
  ItemKind.armor => Symbols.shield_rounded,
  ItemKind.consumable => Symbols.science_rounded,
  ItemKind.quest => Symbols.key_rounded,
  ItemKind.misc => Symbols.deployed_code_rounded,
};

/// Строит страницы и формы правки по текущему снимку мира.
class WorldPages {
  const WorldPages(this.world, this.repo, this.c);
  final World world;
  final ContentRepo repo;
  final WorldSnapshot c;

  Widget location(Location l) {
    final here = [
      for (final ch in c.characters)
        if (ch.locationId == l.id) ch,
    ];
    return Builder(
      builder: (context) => ObjectPage(
        icon: Symbols.landscape_rounded,
        title: l.title,
        kind: 'Локация · ур. ${l.levelMin}–${l.levelMax}',
        cover: true,
        description: l.description,
        edit: () => NewLocationScreen(
          world: world,
          repo: repo,
          editing: l,
          snapshot: c,
        ),
        sections: [
          if (here.isNotEmpty)
            (
              icon: Symbols.groups_rounded,
              title: 'Кто здесь · ${here.length}',
              child: Rail([
                for (final ch in here)
                  PortraitCard(
                    key: Key('who-${ch.slug}'),
                    icon: characterIcon(ch),
                    title: ch.title,
                    stats: [
                      (Symbols.favorite_rounded, '${ch.hp}'),
                      (Symbols.swords_rounded, '${ch.attack}'),
                    ],
                    onTap: () => openDeeper(context, character(ch)),
                  ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget character(Character ch) {
    final home = c.locations.where((l) => l.id == ch.locationId).firstOrNull;
    final items = {for (final i in c.items) i.id: i};
    return ObjectPage(
      icon: characterIcon(ch),
      title: ch.title,
      kind: ch.role.label,
      path: [?home?.title],
      description: ch.description,
      tiles: [
        StatTile(Symbols.military_tech_rounded, 'Уровень', '${ch.level}'),
        StatTile(Symbols.favorite_rounded, 'Здоровье', '${ch.hp}'),
        StatTile(Symbols.swords_rounded, 'Атака', '${ch.attack}'),
      ],
      edit: () => NewCharacterScreen(
        world: world,
        repo: repo,
        locations: c.locations,
        items: c.items,
        editing: ch,
        snapshot: c,
      ),
      sections: [
        if (ch.loot.isNotEmpty)
          (
            icon: Symbols.inventory_2_rounded,
            title: 'Добыча',
            child: Rail([
              for (final d in ch.loot)
                PortraitCard(
                  icon: items[d.itemId] == null
                      ? Symbols.deployed_code_rounded
                      : itemIcon(items[d.itemId]!),
                  title: items[d.itemId]?.title ?? '?',
                  stats: [(Symbols.percent_rounded, d.chanceLabel)],
                ),
            ]),
          ),
      ],
    );
  }

  Widget item(Item i) => ObjectPage(
    icon: itemIcon(i),
    title: i.title,
    kind: '${i.kind.label} · ${i.rarity.label}',
    tiles: [
      StatTile(Symbols.military_tech_rounded, 'Уровень', '${i.level}'),
      if (i.damage case final d?)
        StatTile(Symbols.swords_rounded, 'Урон', '$d'),
      if (i.defense case final d?)
        StatTile(Symbols.shield_rounded, 'Защита', '$d'),
      StatTile(Symbols.payments_rounded, 'Цена', '${i.price}'),
    ],
    description: i.source == null ? '' : 'Образец: ${i.source}',
    edit: () =>
        NewItemScreen(world: world, repo: repo, editing: i, snapshot: c),
  );

  Widget quest(Quest q) {
    final lines = q.lines(c.titles);
    return ObjectPage(
      icon: Symbols.flag_rounded,
      title: q.title,
      kind: 'Квест',
      description: q.description,
      edit: () => NewQuestScreen(
        world: world,
        repo: repo,
        locations: c.locations,
        items: c.items,
        characters: c.characters,
        editing: q,
        snapshot: c,
      ),
      sections: [
        (
          icon: Symbols.format_list_numbered_rounded,
          title: 'Кто выдаёт, шаги, награда',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final line in lines)
                ListTile(contentPadding: EdgeInsets.zero, title: Text(line)),
            ],
          ),
        ),
      ],
    );
  }
}
