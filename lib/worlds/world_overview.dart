import 'package:flutter/material.dart';

import '../assistant/history.dart';
import '../check/world_check.dart';

/// Обзор мира (4.2): сколько объектов по видам, сводка проверки, последние изменения.
/// Сводка ведёт на «Проверку мира», изменения — в «Историю».
class WorldOverview extends StatelessWidget {
  const WorldOverview({
    super.key,
    required this.world,
    required this.history,
    required this.onCheck,
    required this.onHistory,
  });

  final WorldSnapshot world;

  /// Наборы изменений, новые сверху.
  final List<ChangeSetEntry> history;
  final VoidCallback onCheck;
  final VoidCallback onHistory;

  /// Сколько последних изменений показываем.
  static const recent = 3;

  @override
  Widget build(BuildContext context) {
    final w = world;
    final problems = checkWorld(w);
    final errors = problems.where((p) => p.severity == Severity.error).length;
    final warnings = problems.length - errors;
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('world-overview'),
      margin: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            key: const Key('overview-counts'),
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(
              'Локаций ${w.locations.length} · Предметов ${w.items.length} · '
              'Персонажей ${w.characters.length} · Квестов ${w.quests.length}',
            ),
          ),
          ListTile(
            key: const Key('overview-check'),
            leading: Icon(
              errors > 0 ? Icons.error : Icons.fact_check,
              color: errors > 0 ? colors.error : null,
            ),
            title: Text(
              problems.isEmpty
                  ? 'Проблем не найдено'
                  : 'Ошибок: $errors · Предупреждений: $warnings',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onCheck,
          ),
          ListTile(
            key: const Key('overview-history'),
            leading: const Icon(Icons.history),
            title: Text(
              history.isEmpty
                  ? 'Изменений пока не было'
                  : 'Последние изменения',
            ),
            subtitle: history.isEmpty
                ? null
                : Text(
                    [
                      for (final s in history.take(recent))
                        '${s.status.label}: '
                            '${s.summary.isEmpty ? s.request : s.summary}',
                    ].join('\n'),
                  ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onHistory,
          ),
        ],
      ),
    );
  }
}
