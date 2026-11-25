import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../assistant/assistant_service.dart';
import '../content/content_repo.dart';
import '../help/help.dart';
import '../open5e/open5e_api.dart';
import 'new_world_screen.dart';
import 'world_home.dart';
import '../ui/cover_card.dart';
import '../ui/messages.dart';
import '../ui/parts.dart';
import 'world.dart';
import 'worlds_repo.dart';

class WorldsScreen extends StatefulWidget {
  const WorldsScreen({
    super.key,
    required this.repo,
    required this.content,
    required this.assistant,
    required this.onSignOut,
    this.open5e = const HttpOpen5e(),
  });

  final WorldsRepo repo;
  final ContentRepo content;
  final AssistantService assistant;
  final VoidCallback onSignOut;
  final Open5eApi open5e;

  @override
  State<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends State<WorldsScreen> {
  late Future<List<World>> _worlds = widget.repo.listMine();

  void _reload() {
    setState(() {
      _worlds = widget.repo.listMine();
    });
  }

  Future<void> _openNew() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewWorldScreen(repo: widget.repo)),
    );
    if (created == true) _reload();
  }

  /// Шторка мира (вид А): имя шапкой, «Изменить», «Удалить» красным.
  Future<void> _manage(World w) async {
    final what = await showActionSheet<String>(
      context,
      builder: (context) => SheetLayout(
        key: const Key('world-sheet'),
        kind: SheetKind.plain,
        icon: Symbols.public_rounded,
        title: w.title,
        body: [
          _menuRow(
            context,
            key: const Key('world-edit'),
            icon: Symbols.edit_rounded,
            label: 'Изменить',
            value: 'edit',
          ),
          _menuRow(
            context,
            key: const Key('world-delete'),
            icon: Symbols.delete_forever_rounded,
            label: 'Удалить',
            value: 'delete',
            danger: true,
          ),
        ],
        actions: const [],
      ),
    );
    if (!mounted || what == null) return;
    if (what == 'edit') {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => NewWorldScreen(repo: widget.repo, editing: w),
        ),
      );
      if (saved == true) _reload();
    } else {
      await _delete(w);
    }
  }

  Widget _menuRow(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    bool danger = false,
  }) {
    final s = Theme.of(context).colorScheme;
    final color = danger ? s.error : s.onSurface;
    return InkWell(
      key: key,
      onTap: () => Navigator.of(context).pop(value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: s.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          spacing: 14,
          children: [
            Icon(icon, color: danger ? s.error : s.onSurfaceVariant),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Удаление мира необратимо: красная заливка «Удалить навсегда», «Без отката».
  Future<void> _delete(World w) async {
    final (objects, sets) = await _sizeOf(w);
    if (!mounted) return;
    final yes = await confirmAction(
      context,
      title: 'Удалить мир?',
      icon: Symbols.delete_forever_rounded,
      kind: SheetKind.danger,
      subject: SheetSubject(Symbols.public_rounded, w.title),
      facts: [
        if (objects != null)
          SheetFact(Symbols.landscape_rounded, 'Объектов: $objects'),
        if (sets != null)
          SheetFact(Symbols.history_rounded, 'Наборов истории: $sets'),
        const SheetFact(
          Symbols.delete_forever_rounded,
          'Без отката',
          tone: FactTone.hot,
        ),
      ],
      action: 'Удалить навсегда',
      actionIcon: Symbols.delete_forever_rounded,
    );
    if (!yes) return;
    try {
      await widget.repo.delete(w.id);
      if (mounted) showDone(context, 'Мир удалён: ${w.title}');
    } catch (e) {
      if (mounted) showDone(context, 'Не удалось удалить: $e');
    }
    _reload();
  }

  /// Сколько уйдёт вместе с миром; не узнали — шторка обойдётся без чисел.
  Future<(int?, int?)> _sizeOf(World w) async {
    try {
      final (snap, history) = await (
        widget.content.snapshot(w.id),
        widget.content.history(w.id),
      ).wait;
      final objects =
          snap.locations.length +
          snap.items.length +
          snap.characters.length +
          snap.quests.length +
          snap.events.length;
      return (objects, history.length);
    } catch (_) {
      return (null, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Стрелки «назад» здесь нет — заголовок с тем же отступом, что карточки миров.
        titleSpacing: 16,
        title: const Text('Мои миры'),
        actions: [
          IconButton(
            key: const Key('sign-out'),
            tooltip: 'Выйти',
            icon: const Icon(Symbols.logout_rounded),
            onPressed: widget.onSignOut,
          ),
          const HelpAction('worlds'),
        ],
      ),
      // Полоса внизу, а не плавающая кнопка: плавающая закрывала строки списка.
      // Список уходит под полосу, как под край экрана; в конце — отступ под неё.
      extendBody: true,
      bottomNavigationBar: BottomAction(
        key: const Key('new-world'),
        onPressed: _openNew,
        icon: Symbols.add_rounded,
        label: 'Новый мир',
      ),
      body: FutureBuilder<List<World>>(
        future: _worlds,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Не удалось загрузить миры: ${snap.error}'),
            );
          }
          final worlds = snap.data!;
          if (worlds.isEmpty) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              for (final w in worlds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CoverCard(
                    title: w.title,
                    icon: Symbols.public_rounded,
                    seed: w.id,
                    caption: _subtitle(w),
                    onLongPress: () => _manage(w),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorldHome(
                          world: w,
                          repo: widget.content,
                          assistant: widget.assistant,
                          open5e: widget.open5e,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _subtitle(World w) {
    final levels = 'Уровни ${w.levelMin}–${w.levelMax}';
    return w.tone.isEmpty ? levels : '$levels · ${w.tone}';
  }
}

/// Пустой список: что это за место и что нажать.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Symbols.public_rounded, size: 56, color: s.onSurfaceVariant),
            Text(
              'Миров пока нет',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Нажми «Новый мир» — и начни с названия и диапазона уровней',
              textAlign: TextAlign.center,
              style: TextStyle(color: s.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
