import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import '../assistant/assistant_screen.dart';
import '../assistant/assistant_service.dart';
import '../assistant/history.dart';
import '../assistant/history_screen.dart';
import '../worlds/world_overview.dart';
import '../check/check_screen.dart';
import '../check/world_check.dart';
import '../export/export_action.dart';
import '../open5e/open5e_api.dart';
import '../worlds/world.dart';
import 'content_repo.dart';
import 'filters.dart';
import 'world_actions.dart';
import 'world_sections.dart';
import '../ui/parts.dart';

/// Мир изнутри: локации, события в них, предметы, персонажи и квесты, у каждого раздела своя кнопка «+».
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

  void _toggleFilters(String section) => setState(() {
    _filtersOpen.contains(section)
        ? _filtersOpen.remove(section)
        : _filtersOpen.add(section);
  });

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
        actions: worldActions(
          onHistory: _openHistory,
          onCheck: _openCheck,
          onExport: _export,
        ),
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
          final sections = WorldSections(
            context: context,
            world: widget.world,
            repo: widget.repo,
            open5e: widget.open5e,
            assistant: widget.assistant,
            open: _open,
            filter: _filter,
            setFilter: _setFilter,
            filtersOpen: _filtersOpen,
            toggleFilters: _toggleFilters,
          );
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              HelpCorner(
                'world',
                child: WorldOverview(
                  world: c,
                  history: history,
                  onCheck: _openCheck,
                  onHistory: _openHistory,
                ),
              ),
              ...sections.locations(c),
              const Divider(),
              ...sections.events(c),
              const Divider(),
              ...sections.items(c),
              const Divider(),
              ...sections.characters(c),
              const Divider(),
              ...sections.quests(c),
            ],
          );
        },
      ),
    );
  }
}
