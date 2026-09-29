// Страницы объектов мира: локация (кто здесь), персонаж (добыча), предмет, квест (шаги).
// Правка — прежние формы New*Screen по кнопке ✏.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../ui/object_page.dart';
import '../ui/parts.dart';
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
        coverSeed: l.slug,
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
                  stats: [(Symbols.casino_rounded, d.chanceLabel)],
                ),
            ]),
          ),
      ],
    );
  }

  /// Предмет: кто роняет (с шансом), какой квест требует, какой даёт наградой.
  Widget item(Item i) {
    final droppers = [
      for (final ch in c.characters)
        for (final d in ch.loot)
          if (d.itemId == i.id) (ch, d),
    ];
    final needs = [
      for (final q in c.quests)
        if (q.steps.any(
          (s) => s.kind == StepKind.collect && s.targetId == i.id,
        ))
          q,
    ];
    final gives = [
      for (final q in c.quests)
        if (q.rewardIds.contains(i.id)) q,
    ];
    return Builder(
      builder: (context) => ObjectPage(
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
        sections: [
          (
            icon: Symbols.link_rounded,
            title: 'Связи',
            // Нет связей — одна строка: это и подсказка к проверке «нельзя получить».
            child: droppers.isEmpty && needs.isEmpty && gives.isEmpty
                ? const Text(
                    'Предмет ни с чем не связан',
                    key: Key('item-no-links'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (ch, d) in droppers)
                        LinkRow(
                          key: Key('link-${ch.slug}'),
                          icon: characterIcon(ch),
                          text: 'Роняет: ${ch.title} · ${d.chanceLabel}',
                          onTap: () => openDeeper(context, character(ch)),
                        ),
                      for (final q in needs)
                        LinkRow(
                          key: Key('link-need-${q.slug}'),
                          icon: Symbols.flag_rounded,
                          text: 'Нужен в квесте: ${q.title}',
                          onTap: () => openDeeper(context, quest(q)),
                        ),
                      for (final q in gives)
                        LinkRow(
                          key: Key('link-reward-${q.slug}'),
                          icon: Symbols.redeem_rounded,
                          text: 'Награда за квест: ${q.title}',
                          onTap: () => openDeeper(context, quest(q)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Квест: выдающий, шаги, награды — ячейками; каждая ведёт на свой объект.
  Widget quest(Quest q) {
    final byId = <String, Widget Function()>{
      for (final ch in c.characters) ch.id: () => character(ch),
      for (final i in c.items) i.id: () => item(i),
      for (final l in c.locations) l.id: () => location(l),
    };
    IconData iconOf(StepKind? k, bool giver) => switch (k) {
      StepKind.talk => Symbols.forum_rounded,
      StepKind.kill => Symbols.skull_rounded,
      StepKind.collect => Symbols.inventory_2_rounded,
      StepKind.visit => Symbols.location_on_rounded,
      null when giver => Symbols.person_rounded,
      null => Symbols.redeem_rounded,
    };
    final rows = q.rows(c.titles);
    return Builder(
      builder: (context) => ObjectPage(
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
              spacing: 8,
              children: [
                for (final (k, r) in rows.indexed)
                  LinkRow(
                    boxed: true,
                    icon: iconOf(r.step, k == 0),
                    text: r.text,
                    onTap: switch (byId[r.targetId]) {
                      final page? => () => openDeeper(context, page()),
                      null => null,
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
