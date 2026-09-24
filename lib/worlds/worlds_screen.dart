import 'package:flutter/material.dart';

import '../assistant/assistant_service.dart';
import '../content/content_repo.dart';
import '../content/world_screen.dart';
import 'new_world_screen.dart';
import 'world.dart';
import 'worlds_repo.dart';

class WorldsScreen extends StatefulWidget {
  const WorldsScreen({
    super.key,
    required this.repo,
    required this.content,
    required this.assistant,
    required this.onSignOut,
  });

  final WorldsRepo repo;
  final ContentRepo content;
  final AssistantService assistant;
  final VoidCallback onSignOut;

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
            icon: const Icon(Icons.logout),
            onPressed: widget.onSignOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-world'),
        onPressed: _openNew,
        icon: const Icon(Icons.add),
        label: const Text('Новый мир'),
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
            return const Center(child: Text('Миров пока нет'));
          }
          return ListView(
            children: [
              for (final w in worlds)
                ListTile(
                  title: Text(w.title),
                  subtitle: Text(_subtitle(w)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorldScreen(
                        world: w,
                        repo: widget.content,
                        assistant: widget.assistant,
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
