import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../assistant/assistant_service.dart';
import '../map/holst_screen.dart';
import '../map/map_screen.dart';
import '../open5e/open5e_api.dart';
import '../open5e/open5e_screen.dart';
import '../ui/cover_card.dart';
import '../worlds/world.dart';
import 'content_repo.dart';
import 'event_pages.dart';
import 'filter_bar.dart';
import 'filters.dart';
import 'new_character_screen.dart';
import 'new_event_screen.dart';
import 'new_item_screen.dart';
import 'new_location_screen.dart';
import 'new_quest_screen.dart';
import 'world_pages.dart';

/// Разделы экрана мира (локации, события, предметы, персонажи, квесты) —
/// строки списка и заголовки с «+». Состояние живёт в экране мира,
/// сюда оно приходит параметрами.
class WorldSections {
  WorldSections({
    required this.context,
    required this.world,
    required this.repo,
    required this.open5e,
    required this.assistant,
    required this.open,
    required this.filter,
    required this.setFilter,
    required this.filtersOpen,
    required this.toggleFilters,
  });

  final BuildContext context;

  /// Ассистент фразы — для «Менять» на холсте.
  final AssistantService assistant;
  final World world;
  final ContentRepo repo;
  final Open5eApi open5e;

  /// Открыть форму или экран; после возврата с true мир перечитывается.
  final Future<void> Function(Widget screen) open;
  final ContentFilter filter;
  final void Function(ContentFilter) setFilter;
  final Set<String> filtersOpen;
  final void Function(String section) toggleFilters;

  Widget _filterToggle(String section, int active) => FilterToggle(
    section: section,
    active: active,
    onPressed: () => toggleFilters(section),
  );

  WorldPages _pages(WorldSnapshot c) => WorldPages(world, repo, c);

  /// Заголовок раздела с «+»; [lead] — ещё одна кнопка перед «+» (карта у локаций).
  Widget _header(
    String title,
    Key addKey,
    String tooltip,
    Widget form, {
    Widget? lead,
  }) => ListTile(
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?lead,
        IconButton(
          key: addKey,
          tooltip: tooltip,
          icon: const Icon(Symbols.add_rounded),
          onPressed: () => open(form),
        ),
      ],
    ),
  );

  /// Строка объекта в списке: значок и имя, подробности — на его странице.
  Widget _row(
    String slug,
    IconData icon,
    String title,
    Widget page, {
    String? subtitle,
  }) => ListTile(
    key: Key('open-$slug'),
    leading: CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Symbols.chevron_right_rounded),
    onTap: () => open(page),
  );

  List<Widget> locations(WorldSnapshot c) => [
    _header(
      'Локации',
      const Key('new-location'),
      'Новая локация',
      NewLocationScreen(world: world, repo: repo, locations: c.locations),
      lead: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('holst-open'),
            tooltip: 'Холст мира',
            icon: const Icon(Symbols.dashboard_rounded),
            onPressed: () => open(
              HolstScreen(
                world: world,
                repo: repo,
                snapshot: c,
                assistant: assistant,
              ),
            ),
          ),
          IconButton(
            key: const Key('map-open'),
            tooltip: 'Карта',
            icon: const Icon(Symbols.map_rounded),
            onPressed: () =>
                open(MapScreen(world: world, repo: repo, snapshot: c)),
          ),
        ],
      ),
    ),
    if (c.locations.isEmpty) const ListTile(subtitle: Text('Локаций пока нет')),
    for (final l in c.locations)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: CoverCard(
          key: Key('open-${l.slug}'),
          title: l.title,
          icon: Symbols.landscape_rounded,
          seed: l.slug,
          caption: 'ур. ${l.levelMin}–${l.levelMax}',
          counters: [
            (
              Symbols.groups_rounded,
              c.characters.where((ch) => ch.locationId == l.id).length,
            ),
            // Молния — сцены прямо в этом месте; нет сцен — нет значка.
            if (c.events.any((e) => e.locationId == l.id))
              (eventIcon, c.events.where((e) => e.locationId == l.id).length),
          ],
          onTap: () => open(_pages(c).location(l)),
        ),
      ),
  ];

  /// Предметы с фильтром по редкости и виду (4.3).
  List<Widget> items(WorldSnapshot c) {
    final shown = filter.items(c.items);
    return [
      _header(
        'Предметы',
        const Key('new-item'),
        'Новый предмет',
        NewItemScreen(world: world, repo: repo),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('open5e-open'),
          icon: const Icon(Symbols.local_library_rounded),
          label: const Text('Образец из Open5e'),
          onPressed: () => open(
            Open5eScreen(world: world, snapshot: c, repo: repo, api: open5e),
          ),
        ),
      ),
      if (c.items.isNotEmpty)
        _filterToggle('items', filter.rarities.length + filter.kinds.length),
      if (c.items.isNotEmpty && filtersOpen.contains('items'))
        ...itemFilters(filter, setFilter),
      if (c.items.isEmpty)
        const ListTile(subtitle: Text('Предметов пока нет'))
      else if (shown.isEmpty)
        const ListTile(
          key: Key('items-filtered-empty'),
          subtitle: Text('Под фильтр ничего не подходит'),
        ),
      for (final i in shown)
        _row(i.slug, itemIcon(i), i.title, _pages(c).item(i)),
    ];
  }

  /// Персонажи с фильтром по роли (4.3).
  List<Widget> characters(WorldSnapshot c) {
    final shown = filter.characters(c.characters);
    return [
      _header(
        'Персонажи',
        const Key('new-character'),
        'Новый персонаж',
        NewCharacterScreen(
          world: world,
          repo: repo,
          locations: c.locations,
          items: c.items,
        ),
      ),
      if (c.characters.isNotEmpty)
        _filterToggle('characters', filter.roles.length),
      if (c.characters.isNotEmpty && filtersOpen.contains('characters'))
        roleFilter(filter, setFilter),
      if (c.characters.isEmpty)
        const ListTile(subtitle: Text('Персонажей пока нет'))
      else if (shown.isEmpty)
        const ListTile(
          key: Key('characters-filtered-empty'),
          subtitle: Text('Под фильтр ничего не подходит'),
        ),
      for (final ch in shown)
        _row(ch.slug, characterIcon(ch), ch.title, _pages(c).character(ch)),
    ];
  }

  List<Widget> quests(WorldSnapshot c) => [
    _header(
      'Квесты',
      const Key('new-quest'),
      'Новый квест',
      NewQuestScreen(
        world: world,
        repo: repo,
        locations: c.locations,
        items: c.items,
        characters: c.characters,
        events: c.events,
      ),
    ),
    if (c.quests.isEmpty) const ListTile(subtitle: Text('Квестов пока нет')),
    for (final q in c.quests)
      _row(q.slug, Symbols.flag_rounded, q.title, _pages(c).quest(q)),
  ];

  List<Widget> events(WorldSnapshot c) => [
    _header(
      'События',
      const Key('new-event'),
      'Новое событие',
      NewEventScreen(world: world, repo: repo, snapshot: c),
    ),
    // Пустой раздел объясняет, что такое событие: без этого слово ничего не говорит.
    if (c.events.isEmpty)
      const ListTile(key: Key('events-empty'), subtitle: Text(eventsHint)),
    // Сцены идут по местам: под названием — где сцена и что в ней.
    for (final e in eventsByPlace(c))
      _row(
        e.slug,
        eventIcon,
        e.title,
        _pages(c).event(e),
        subtitle: eventLine(c, e),
      ),
  ];
}
