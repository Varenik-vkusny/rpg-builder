import 'package:flutter/material.dart';

import '../assistant/assistant_screen.dart';
import '../assistant/assistant_service.dart';
import '../assistant/scope.dart';
import '../content/content_repo.dart';
import '../worlds/world.dart';
import 'world_check.dart';

/// «Проверка мира»: все ошибки и предупреждения мира одним списком.
/// У каждой проблемы — «Исправить»: ассистент с областью и просьбой (3.8).
/// Закрывается с true, если мир менялся (исправление применили).
class CheckScreen extends StatefulWidget {
  const CheckScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.assistant,
  });

  final World world;
  final ContentRepo repo;
  final AssistantService assistant;

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  late Future<WorldSnapshot> _world = _load();
  bool _changed = false;

  Future<WorldSnapshot> _load() => widget.repo.snapshot(widget.world.id);

  /// Ассистент на этой проблеме: область — объект проблемы (или связанный с ним),
  /// просьба — сама проблема. Применили — перечитать проверку.
  Future<void> _fix(WorldSnapshot w, Problem p) async {
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssistantScreen(
          world: widget.world,
          snapshot: w,
          assistant: widget.assistant,
          repo: widget.repo,
          initialScope: scopeForObject(w, p.objectId),
          initialRequest: 'Исправь проблему проверки мира: ${p.message}',
        ),
      ),
    );
    if (applied == true) {
      _changed = true;
      setState(() {
        _world = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Проверка мира')),
        body: FutureBuilder<WorldSnapshot>(
          future: _world,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text('Не удалось загрузить мир: ${snap.error}'),
              );
            }
            final problems = checkWorld(snap.data!);
            int count(Severity s) =>
                problems.where((p) => p.severity == s).length;
            return ListView(
              children: [
                ListTile(
                  key: const Key('check-summary'),
                  title: Text(widget.world.title),
                  subtitle: Text(
                    problems.isEmpty
                        ? 'Проблем не найдено'
                        : 'Ошибок: ${count(Severity.error)} · '
                              'Предупреждений: ${count(Severity.warning)}',
                  ),
                ),
                const Divider(),
                for (final (i, p) in problems.indexed)
                  ListTile(
                    leading: p.severity == Severity.error
                        ? Icon(Icons.error, color: colors.error)
                        : const Icon(Icons.warning_amber, color: Colors.orange),
                    title: Text(p.message),
                    subtitle: Text(p.severity.label),
                    trailing: TextButton(
                      key: Key('fix-$i'),
                      onPressed: () => _fix(snap.data!, p),
                      child: const Text('Исправить'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
