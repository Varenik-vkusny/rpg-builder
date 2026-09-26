import 'package:flutter/material.dart';

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
import 'character.dart';
import 'content_repo.dart';
import 'filter_bar.dart';
import 'filters.dart';
import 'item.dart';
import 'new_character_screen.dart';
import 'new_item_screen.dart';
import 'new_location_screen.dart';
import 'new_quest_screen.dart';
import 'quest.dart';

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

  /// Кнопка «Фильтр» раздела: сколько выбрано, по нажатию — чипы.
  Widget _filterToggle(String section, int active) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: Key('filter-$section'),
      icon: const Icon(Icons.filter_list),
      label: Text(active == 0 ? 'Фильтр' : 'Фильтр: $active'),
      onPressed: () => setState(() {
        _filtersOpen.contains(section)
            ? _filtersOpen.remove(section)
            : _filtersOpen.add(section);
      }),
    ),
  );

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
          icon: const Icon(Icons.add),
          onPressed: () => _open(form),
        ),
      );

  /// Квест в списке: выдающий, шаги по порядку, награды — строками.
  /// Тап открывает форму квеста в режиме правки.
  Widget _questTile(Quest q, WorldSnapshot c) => ListTile(
    key: Key('open-${q.slug}'),
    leading: const Icon(Icons.flag),
    title: Text(q.title),
    subtitle: Text(q.lines(c.titles).join('\n')),
    isThreeLine: true,
    onTap: () => _open(
      NewQuestScreen(
        world: widget.world,
        repo: widget.repo,
        locations: c.locations,
        items: c.items,
        characters: c.characters,
        editing: q,
        snapshot: c,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    return Scaffold(
      appBar: AppBar(
        title: Text(world.title),
        actions: [
          IconButton(
            key: const Key('assistant-open'),
            tooltip: 'Ассистент',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _openAssistant,
          ),
          IconButton(
            key: const Key('history-open'),
            tooltip: 'История изменений',
            icon: const Icon(Icons.history),
            onPressed: _openHistory,
          ),
          IconButton(
            key: const Key('check-world'),
            tooltip: 'Проверка мира',
            icon: const Icon(Icons.fact_check),
            onPressed: _openCheck,
          ),
          IconButton(
            key: const Key('world-export'),
            tooltip: 'Экспорт в JSON',
            icon: const Icon(Icons.ios_share),
            onPressed: _export,
          ),
        ],
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
      ListTile(
        key: Key('open-${l.slug}'),
        leading: const Icon(Icons.place),
        title: Text(l.title),
        subtitle: Text('Уровни ${l.levelMin}–${l.levelMax}'),
        onTap: () => _open(
          NewLocationScreen(
            world: widget.world,
            repo: widget.repo,
            editing: l,
            snapshot: c,
          ),
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
          icon: const Icon(Icons.local_library),
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
      if (c.items.isNotEmpty && _filtersOpen.contains('items')) ...[
        FilterBar(
          prefix: 'rarity',
          values: Rarity.values,
          label: (r) => r.label,
          selected: _filter.rarities,
          onToggle: (r) => setState(() {
            _filter = _filter.copyWith(
              rarities: ContentFilter.toggle(_filter.rarities, r),
            );
          }),
        ),
        const SizedBox(height: 4),
        FilterBar(
          prefix: 'kind',
          values: ItemKind.values,
          label: (k) => k.label,
          selected: _filter.kinds,
          onToggle: (k) => setState(() {
            _filter = _filter.copyWith(
              kinds: ContentFilter.toggle(_filter.kinds, k),
            );
          }),
        ),
      ],
      if (c.items.isEmpty)
        const ListTile(subtitle: Text('Предметов пока нет'))
      else if (shown.isEmpty)
        const ListTile(
          key: Key('items-filtered-empty'),
          subtitle: Text('Под фильтр ничего не подходит'),
        ),
      for (final i in shown)
        ListTile(
          key: Key('open-${i.slug}'),
          leading: const Icon(Icons.inventory_2),
          title: Text(i.title),
          subtitle: Text(i.summary),
          onTap: () => _open(
            NewItemScreen(
              world: widget.world,
              repo: widget.repo,
              editing: i,
              snapshot: c,
            ),
          ),
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
        FilterBar(
          prefix: 'role',
          values: Role.values,
          label: (r) => r.label,
          selected: _filter.roles,
          onToggle: (r) => setState(() {
            _filter = _filter.copyWith(
              roles: ContentFilter.toggle(_filter.roles, r),
            );
          }),
        ),
      if (c.characters.isEmpty)
        const ListTile(subtitle: Text('Персонажей пока нет'))
      else if (shown.isEmpty)
        const ListTile(
          key: Key('characters-filtered-empty'),
          subtitle: Text('Под фильтр ничего не подходит'),
        ),
      for (final ch in shown)
        ListTile(
          key: Key('open-${ch.slug}'),
          leading: const Icon(Icons.person),
          title: Text(ch.title),
          subtitle: Text(
            ch.summary(
              {for (final l in c.locations) l.id: l.title},
              {for (final i in c.items) i.id: i.title},
            ),
          ),
          onTap: () => _open(
            NewCharacterScreen(
              world: widget.world,
              repo: widget.repo,
              locations: c.locations,
              items: c.items,
              editing: ch,
              snapshot: c,
            ),
          ),
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
    for (final q in c.quests) _questTile(q, c),
  ];
}
