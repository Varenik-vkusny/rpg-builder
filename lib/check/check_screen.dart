import 'package:flutter/material.dart';

import '../content/content_repo.dart';
import '../worlds/world.dart';
import 'world_check.dart';

/// «Проверка мира»: все ошибки и предупреждения мира одним списком.
class CheckScreen extends StatelessWidget {
  const CheckScreen({super.key, required this.world, required this.repo});

  final World world;
  final ContentRepo repo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка мира')),
      body: FutureBuilder<WorldSnapshot>(
        future: repo.snapshot(world.id),
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
                title: Text(world.title),
                subtitle: Text(
                  problems.isEmpty
                      ? 'Проблем не найдено'
                      : 'Ошибок: ${count(Severity.error)} · '
                            'Предупреждений: ${count(Severity.warning)}',
                ),
              ),
              const Divider(),
              for (final p in problems)
                ListTile(
                  leading: p.severity == Severity.error
                      ? Icon(Icons.error, color: colors.error)
                      : const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text(p.message),
                  subtitle: Text(p.severity.label),
                ),
            ],
          );
        },
      ),
    );
  }
}
