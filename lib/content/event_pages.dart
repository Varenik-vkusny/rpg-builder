// Страница события (5б.1): место сцены путём, враги с числом, предметы;
// раздел «События» на странице места (5б.2); строка события в списке мира.
// Правка — форма NewEventScreen по кнопке ✏.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../ui/object_page.dart';
import 'event.dart';
import 'location.dart';
import 'nesting.dart';
import 'new_event_screen.dart';
import 'world_pages.dart';

const eventIcon = Symbols.bolt_rounded;

/// Что такое событие — одной фразой там, где событий ещё нет.
const eventsHint =
    'Событие — сцена в месте: кто нападает, сколько их и что там лежит. '
    'Например, засада у лебёдки: 3 слизня и ключ.';

/// События мира по местам: сначала по пути места («Копи › Штольня №3»), потом по названию.
List<Event> eventsByPlace(WorldSnapshot c) {
  final places = {for (final l in c.locations) l.id: pathOf(c.locations, l)};
  String key(Event e) => '${places[e.locationId] ?? ''}\n${e.title}';
  return [...c.events]..sort((a, b) => key(a).compareTo(key(b)));
}

/// «Копи › Штольня №3 · Слизень × 3 · Ключ» — где сцена и что в ней.
String eventLine(WorldSnapshot c, Event e) {
  final place = c.locations.where((l) => l.id == e.locationId).firstOrNull;
  final t = c.titles;
  return [
    place == null ? '?' : pathOf(c.locations, place),
    // Неразрывные пробелы: «Слизень × 3» не рвётся между строками.
    for (final x in e.enemies)
      '${t[x.characterId] ?? '?'} × ${x.amount}',
    for (final id in e.itemIds) t[id] ?? '?',
  ].join(' · ');
}

extension EventPages on WorldPages {
  /// «События»: сцены этого места и всех вложенных в него; нажатие открывает событие.
  /// У сцены вложенного места на карточке подписано, где она идёт. Раздел есть и у места
  /// без сцен: отсюда сцену создают сразу в этом месте.
  ObjectSection eventsSection(BuildContext context, Location l) {
    final here = eventsIn(c.locations, c.events, l.id);
    final places = {for (final p in c.locations) p.id: p.title};
    void add() => openDeeper(
      context,
      NewEventScreen(world: world, repo: repo, snapshot: c, locationId: l.id),
    );
    // Кнопка — слева под сценами: справа внизу страницы стоит плавающая «править».
    final addButton = TextButton.icon(
      key: const Key('event-add'),
      onPressed: add,
      icon: const Icon(Symbols.add_rounded),
      label: const Text('Добавить событие'),
    );
    Widget block(Widget top) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [top, addButton],
    );
    if (here.isEmpty) {
      return (
        icon: eventIcon,
        title: 'События',
        child: block(const Text(eventsHint)),
      );
    }
    return (
      icon: eventIcon,
      title: 'События · ${here.length}',
      child: block(
        Rail([
        for (final e in here)
          PortraitCard(
            key: Key('event-${e.slug}'),
            icon: eventIcon,
            title: e.title,
            caption: e.locationId == l.id ? null : places[e.locationId],
            // Сколько врагов в сцене всего; сцена без врагов — без числа.
            stats: [
              if (e.enemies.isNotEmpty)
                (
                  Symbols.skull_rounded,
                  '${e.enemies.fold(0, (n, x) => n + x.amount)}',
                ),
            ],
            onTap: () => openDeeper(context, event(e)),
          ),
        ]),
      ),
    );
  }

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
