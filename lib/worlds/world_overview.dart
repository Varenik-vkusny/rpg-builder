import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
          Padding(
            key: const Key('overview-counts'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              spacing: 8,
              children: [
                _Count(
                  'locations',
                  Symbols.landscape_rounded,
                  'Места',
                  w.locations.length,
                ),
                _Count(
                  'items',
                  Symbols.deployed_code_rounded,
                  'Предметы',
                  w.items.length,
                ),
                _Count(
                  'characters',
                  Symbols.groups_rounded,
                  'Персонажи',
                  w.characters.length,
                ),
                _Count(
                  'quests',
                  Symbols.flag_rounded,
                  'Квесты',
                  w.quests.length,
                ),
                _Count(
                  'events',
                  Symbols.bolt_rounded,
                  'События',
                  w.events.length,
                ),
              ],
            ),
          ),
          ListTile(
            key: const Key('overview-check'),
            leading: Icon(
              errors > 0 ? Symbols.error_rounded : Symbols.fact_check_rounded,
              color: errors > 0 ? colors.error : null,
            ),
            title: Text(
              problems.isEmpty
                  ? 'Проблем не найдено'
                  : 'Ошибок: $errors · Предупреждений: $warnings',
            ),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: onCheck,
          ),
          ListTile(
            key: const Key('overview-history'),
            leading: const Icon(Symbols.history_rounded),
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
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: onHistory,
          ),
        ],
      ),
    );
  }
}

/// Счётчик объектов одного вида: значок, число, короткая подпись.
class _Count extends StatelessWidget {
  const _Count(this.kind, this.icon, this.label, this.n);
  final String kind;
  final IconData icon;
  final String label;
  final int n;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        key: Key('count-$kind'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: s.surfaceContainerLow,
          border: Border.all(color: s.outlineVariant),
        ),
        child: Column(
          spacing: 2,
          children: [
            Icon(icon, size: 20, color: s.onSurfaceVariant),
            Text('$n', style: const TextStyle(fontSize: 20)),
            // Пять плиток в ряд узкие: длинная подпись сжимается, а не обрезается.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, color: s.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
