import 'package:flutter/material.dart';

import '../check/world_check.dart';
import 'plan.dart';
import 'plan_apply.dart';
import 'plan_preview.dart';

/// План глазами автора: итог проверки на копии и «было → стало» по каждой операции.
class PlanView extends StatelessWidget {
  const PlanView({super.key, required this.plan, required this.preview});

  final Plan plan;
  final PlanPreview preview;

  @override
  Widget build(BuildContext context) {
    final errors = preview.of(Severity.error).length;
    final warnings = preview.of(Severity.warning).length;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          plan.summary,
          key: const Key('plan-summary'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          errors + warnings == 0
              ? 'Проверка на копии мира: проблем нет'
              : 'Проверка на копии мира — ошибок: $errors · '
                    'предупреждений: $warnings',
          key: const Key('plan-check-summary'),
          style: TextStyle(color: errors > 0 ? theme.colorScheme.error : null),
        ),
        if (preview.outside.isNotEmpty)
          Text(
            'Операций вне области: ${preview.outside.length} — '
            'такой план применить нельзя',
            key: const Key('plan-out-of-scope'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        for (final p in preview.problems) _problem(p, theme),
        const SizedBox(height: 8),
        for (final (i, r) in preview.ops.indexed) _op(i, r, theme),
      ],
    );
  }

  Widget _problem(Problem p, ThemeData theme) => ListTile(
    dense: true,
    leading: p.severity == Severity.error
        ? Icon(Icons.error, color: theme.colorScheme.error)
        : const Icon(Icons.warning_amber, color: Colors.orange),
    title: Text(p.message),
  );

  Widget _op(int i, OpResult r, ThemeData theme) => Card(
    key: Key('plan-op-$i'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(r.title, style: theme.textTheme.titleSmall),
          if (preview.outside[i] case final keys?)
            Text(
              'Вне области: ${keys.join(', ')}',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (r.error != null)
            Text(
              'Не выполнить: ${r.error}',
              style: TextStyle(color: theme.colorScheme.error),
            )
          else if (r.op.action == OpAction.delete && r.changes.isEmpty)
            const Text('удаляется')
          else
            for (final c in r.changes) Text(_change(c)),
        ],
      ),
    ),
  );

  /// «Атака: 14 → 8», «Атака: 14» (новое), «Шанс: 35% → удалено».
  static String _change(FieldChange c) => switch ((c.before, c.after)) {
    (null, final a) => '${c.label}: $a',
    (final b, null) => '${c.label}: $b → удалено',
    (final String b, final String a) =>
      '${c.label}: ${b.isEmpty ? 'пусто' : b} → ${a.isEmpty ? 'пусто' : a}',
  };
}
