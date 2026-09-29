import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../assistant/assistant_service.dart';
import '../content/content_repo.dart';
import '../content/world_screen.dart';
import '../open5e/open5e_api.dart';
import 'new_world_screen.dart';
import '../ui/cover_card.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои миры'),
        actions: [
          IconButton(
            key: const Key('sign-out'),
            tooltip: 'Выйти',
            icon: const Icon(Symbols.logout_rounded),
            onPressed: widget.onSignOut,
          ),
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
                    hue: CoverCard.hueOf(w.title),
                    caption: _subtitle(w),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorldScreen(
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
