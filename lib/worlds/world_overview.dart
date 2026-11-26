import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../assistant/history.dart';
import '../assistant/history_line.dart';
import '../assistant/history_tile.dart';
import '../check/world_check.dart';
import '../ui/check_cells.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: CheckStrip(
              key: const Key('overview-check'),
              errors: errors,
              warnings: warnings,
              onTap: onCheck,
            ),
          ),
          // Вид А (25.11): три мини-ряда той же формы, что в истории; пустую
          // историю не показываем вовсе.
          if (history.isNotEmpty)
            _Recent(world: w, history: history, onHistory: onHistory),
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
            // Высота строки одна у всех плиток — сжатая подпись не делает плитку ниже.
            Container(
              height: MediaQuery.textScalerOf(context).scale(11) * 1.5,
              alignment: Alignment.center,
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

/// «Последние изменения»: мини-ряды истории и «Вся история ›».
class _Recent extends StatelessWidget {
  const _Recent({
    required this.world,
    required this.history,
    required this.onHistory,
  });

  final WorldSnapshot world;
  final List<ChangeSetEntry> history;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final show = valueShower(world);
    final byId = {for (final h in history) h.id: h};
    final line = BorderSide(color: s.outlineVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Последние изменения',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            key: const Key('overview-recent'),
            decoration: BoxDecoration(
              color: s.surfaceContainerLow,
              border: Border.all(color: s.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final h in history.take(WorldOverview.recent))
                  InkWell(
                    onTap: onHistory,
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border(bottom: line)),
                      child: HistoryHead(
                        describe(
                          h,
                          world: world,
                          show: show,
                          original: h.revertsId == null
                              ? null
                              : byId[h.revertsId],
                        ),
                        h.createdAt,
                        mini: true,
                      ),
                    ),
                  ),
                InkWell(
                  key: const Key('overview-history'),
                  onTap: onHistory,
                  child: const SizedBox(
                    height: 48,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 6,
                      children: [
                        Text(
                          'Вся история',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Icon(Symbols.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
