// Страница события (5б.1): место сцены путём, враги с числом, предметы.
// Правка — форма NewEventScreen по кнопке ✏.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/object_page.dart';
import 'event.dart';
import 'nesting.dart';
import 'new_event_screen.dart';
import 'world_pages.dart';

const eventIcon = Symbols.bolt_rounded;

extension EventPages on WorldPages {
  /// Событие: где идёт сцена, кто в ней стоит и что лежит; ячейки ведут на свои объекты.
  Widget event(Event e) {
    final place = c.locations.where((l) => l.id == e.locationId).firstOrNull;
    final characters = {for (final ch in c.characters) ch.id: ch};
    final items = {for (final i in c.items) i.id: i};
    return Builder(
      builder: (context) => ObjectPage(
        icon: eventIcon,
        title: e.title,
        help: 'page.event',
        kind: 'Событие',
        path: [if (place != null) pathOf(c.locations, place)],
        description: e.description,
        edit: () =>
            NewEventScreen(world: world, repo: repo, snapshot: c, editing: e),
        sections: [
          if (e.enemies.isNotEmpty)
            (
              icon: Symbols.skull_rounded,
              title: 'Враги',
              child: Rail([
                for (final x in e.enemies)
                  switch (characters[x.characterId]) {
                    final ch? => PortraitCard(
                      key: Key('enemy-${ch.slug}'),
                      icon: characterIcon(ch),
                      title: ch.title,
                      stats: [(Symbols.groups_rounded, '× ${x.amount}')],
                      onTap: () => openDeeper(context, character(ch)),
                    ),
                    null => PortraitCard(
                      icon: Symbols.skull_rounded,
                      title: '?',
                      stats: [(Symbols.groups_rounded, '× ${x.amount}')],
                    ),
                  },
              ]),
            ),
          if (e.items.isNotEmpty)
            (
              icon: Symbols.inventory_2_rounded,
              title: 'Предметы',
              child: Rail([
                for (final x in e.items)
                  switch (items[x.itemId]) {
                    final i? => PortraitCard(
                      key: Key('event-item-${i.slug}'),
                      icon: itemIcon(i),
                      title: i.title,
                      stats: const [],
                      onTap: () => openDeeper(context, item(i)),
                    ),
                    null => const PortraitCard(
                      icon: Symbols.deployed_code_rounded,
                      title: '?',
                      stats: [],
                    ),
                  },
              ]),
            ),
        ],
      ),
    );
  }
}
