import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../assistant/assistant_screen.dart';
import '../assistant/assistant_service.dart';
import '../assistant/history.dart';
import '../assistant/history_screen.dart';
import '../worlds/world_overview.dart';
import '../check/check_screen.dart';
import '../check/world_check.dart';
import '../export/export_action.dart';
import '../open5e/open5e_api.dart';
import '../open5e/open5e_screen.dart';
import '../worlds/world.dart';
import 'content_repo.dart';
import 'filter_bar.dart';
import 'filters.dart';
import 'new_character_screen.dart';
import 'new_item_screen.dart';
import 'new_location_screen.dart';
import 'new_quest_screen.dart';
import 'world_pages.dart';
import '../ui/cover_card.dart';
import '../ui/parts.dart';

/// Мир изнутри: локации, предметы, персонажи и квесты, у каждого раздела своя кнопка «+».
class WorldScreen extends StatefulWidget {
  const WorldScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.assistant,
    this.open5e = const HttpOpen5e(),
  });

  final World world;
  final ContentRepo repo;
  final AssistantService assistant;

  /// Библиотека образцов (4.6).
  final Open5eApi open5e;

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  late Future<WorldSnapshot> _content = _load();
  late Future<List<ChangeSetEntry>> _history = _loadHistory();

  /// Фильтры списков (4.3) — живут, пока открыт мир.
  ContentFilter _filter = const ContentFilter();

  /// Раскрыты ли чипы фильтра у раздела: «items» / «characters».
  final _filtersOpen = <String>{};

  Widget _filterToggle(String section, int active) => FilterToggle(
    section: section,
    active: active,
    onPressed: () => setState(() {
      _filtersOpen.contains(section)
          ? _filtersOpen.remove(section)
          : _filtersOpen.add(section);
    }),
  );

  void _setFilter(ContentFilter f) => setState(() => _filter = f);

  Future<WorldSnapshot> _load() => widget.repo.snapshot(widget.world.id);
  Future<List<ChangeSetEntry>> _loadHistory() =>
      widget.repo.history(widget.world.id);

  /// Форма или экран, после которого мир мог поменяться: вернулся с true —
  /// перечитать мир и обзор.
  Future<void> _open(Widget screen) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (changed == true) {
      setState(() {
        _content = _load();
        _history = _loadHistory();
      });
    }
  }

  void _openHistory() =>
      _open(HistoryScreen(world: widget.world, repo: widget.repo));

  void _openCheck() => _open(
    CheckScreen(
      world: widget.world,
      repo: widget.repo,
      assistant: widget.assistant,
    ),
  );

  /// Ассистент на текущем снимке мира.
  Future<void> _openAssistant() async {
    final snapshot = await _content;
    if (!mounted) return;
    await _open(
      AssistantScreen(
        world: widget.world,
        snapshot: snapshot,
        assistant: widget.assistant,
        repo: widget.repo,
      ),
    );
  }

  /// Экспорт текущего снимка мира в JSON → «Поделиться» (4.5).
  Future<void> _export() async {
    final snapshot = await _content;
    if (!mounted) return;
    await exportAndShare(context, widget.world, snapshot);
  }

  Widget _header(String title, Key addKey, String tooltip, Widget form) =>
      ListTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: IconButton(
          key: addKey,
          tooltip: tooltip,
          icon: const Icon(Symbols.add_rounded),
          onPressed: () => _open(form),
        ),
      );

  /// Строка объекта в списке: значок и имя, подробности — на его странице.
  Widget _row(String slug, IconData icon, String title, Widget page) =>
      ListTile(
        key: Key('open-$slug'),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(title),
        trailing: const Icon(Symbols.chevron_right_rounded),
        onTap: () => _open(page),
      );

  /// История, проверка и экспорт — значками в шапке мира.
  List<Widget> _actions() => [
    IconButton(
      key: const Key('history-open'),
      tooltip: 'История изменений',
      icon: const Icon(Symbols.history_rounded),
      onPressed: _openHistory,
    ),
    IconButton(
      key: const Key('check-world'),
      tooltip: 'Проверка мира',
      icon: const Icon(Symbols.fact_check_rounded),
      onPressed: _openCheck,
    ),
    IconButton(
      key: const Key('world-export'),
      tooltip: 'Экспорт в JSON',
      icon: const Icon(Symbols.ios_share_rounded),
      onPressed: _export,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        // Название мира — до двух строк, без многоточия.
        title: Text(
          world.title,
          maxLines: 2,
          style: const TextStyle(fontSize: 17, height: 1.15),
        ),
        actions: _actions(),
      ),
      // Полоса внизу, а не плавающая кнопка: плавающая закрывала строки списка.
      // Список уходит под полосу, как под край экрана; в конце — отступ под неё.
      extendBody: true,
      bottomNavigationBar: BottomAction(
        key: const Key('assistant-open'),
        onPressed: _openAssistant,
        icon: Symbols.auto_awesome_rounded,
        label: 'Изменить фразой',
      ),
      body: FutureBuilder(
        future: (_content, _history).wait,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Не удалось загрузить мир: ${snap.error}'),
            );
          }
          final (c, history) = snap.data!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              WorldOverview(
                world: c,
                history: history,
                onCheck: _openCheck,
                onHistory: _openHistory,
              ),
              ..._locations(c),
              const Divider(),
              ..._items(c),
              const Divider(),
              ..._characters(c),
              const Divider(),
              ..._quests(c),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _locations(WorldSnapshot c) => [
    _header(
      'Локации',
      const Key('new-location'),
      'Новая локация',
      NewLocationScreen(world: widget.world, repo: widget.repo),
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
          ],
          onTap: () =>
              _open(WorldPages(widget.world, widget.repo, c).location(l)),
        ),
      ),
  ];

  /// Предметы с фильтром по редкости и виду (4.3).
  List<Widget> _items(WorldSnapshot c) {
    final shown = _filter.items(c.items);
    return [
      _header(
        'Предметы',
        const Key('new-item'),
        'Новый предмет',
        NewItemScreen(world: widget.world, repo: widget.repo),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('open5e-open'),
          icon: const Icon(Symbols.local_library_rounded),
          label: const Text('Образец из Open5e'),
          onPressed: () => _open(
            Open5eScreen(
              world: widget.world,
              snapshot: c,
              repo: widget.repo,
              api: widget.open5e,
            ),
          ),
        ),
      ),
      if (c.items.isNotEmpty)
        _filterToggle('items', _filter.rarities.length + _filter.kinds.length),
      if (c.items.isNotEmpty && _filtersOpen.contains('items'))
        ...itemFilters(_filter, _setFilter),
      if (c.items.isEmpty)
        const ListTile(subtitle: Text('Предметов пока нет'))
      else if (shown.isEmpty)
        const ListTile(
          key: Key('items-filtered-empty'),
          subtitle: Text('Под фильтр ничего не подходит'),
        ),
      for (final i in shown)
        _row(
          i.slug,
          itemIcon(i),
          i.title,
          WorldPages(widget.world, widget.repo, c).item(i),
        ),
    ];
  }

  /// Персонажи с фильтром по роли (4.3).
  List<Widget> _characters(WorldSnapshot c) {
    final shown = _filter.characters(c.characters);
    return [
      _header(
        'Персонажи',
        const Key('new-character'),
        'Новый персонаж',
        NewCharacterScreen(
          world: widget.world,
          repo: widget.repo,
          locations: c.locations,
          items: c.items,
        ),
      ),
      if (c.characters.isNotEmpty)
        _filterToggle('characters', _filter.roles.length),
      if (c.characters.isNotEmpty && _filtersOpen.contains('characters'))
        roleFilter(_filter, _setFilter),
      if (c.characters.isEmpty)
        const ListTile(subtitle: Text('Персонажей пока нет'))
      else if (shown.isEmpty)
        const ListTile(
          key: Key('characters-filtered-empty'),
          subtitle: Text('Под фильтр ничего не подходит'),
        ),
      for (final ch in shown)
        _row(
          ch.slug,
          characterIcon(ch),
          ch.title,
          WorldPages(widget.world, widget.repo, c).character(ch),
        ),
    ];
  }

  List<Widget> _quests(WorldSnapshot c) => [
    _header(
      'Квесты',
      const Key('new-quest'),
      'Новый квест',
      NewQuestScreen(
        world: widget.world,
        repo: widget.repo,
        locations: c.locations,
        items: c.items,
        characters: c.characters,
      ),
    ),
    if (c.quests.isEmpty) const ListTile(subtitle: Text('Квестов пока нет')),
    for (final q in c.quests)
      _row(
        q.slug,
        Symbols.flag_rounded,
        q.title,
        WorldPages(widget.world, widget.repo, c).quest(q),
      ),
  ];
}
