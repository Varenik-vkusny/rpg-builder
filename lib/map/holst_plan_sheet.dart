// Холст мира (5е), «Менять»: строка фразы («что поменять» и область) и лист плана —
// строки «было → стало», проверка, «Отклонить» / «Применить». Голубой — только «Применить».
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/theme.dart';
import 'holst_plan.dart';

/// Фраза ассистенту. [scope] — что меняем словами («Штольня №3»); null — ещё не выбрано.
class ChangeTray extends StatelessWidget {
  const ChangeTray({
    super.key,
    required this.controller,
    required this.scope,
    required this.busy,
    required this.onAsk,
  });

  final TextEditingController controller;
  final String? scope;
  final bool busy;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            children: [
              Icon(
                Symbols.location_on_rounded,
                size: 18,
                color: s.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  scope ?? 'Нажми место или объект',
                  key: const Key('holst-scope'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: scope == null ? s.onSurfaceVariant : s.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('holst-phrase'),
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Что поменять?',
                    isDense: true,
                    prefixIcon: Icon(Symbols.forum_rounded),
                  ),
                ),
              ),
              FilledButton(
                key: const Key('holst-ask'),
                onPressed: busy || scope == null ? null : onAsk,
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                child: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('План'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Лист плана. [shown] — сколько строк уже проступило; [big] — список вместо показа по шагу;
/// [peek] — список свёрнут, смотрим холст.
class PlanSheet extends StatelessWidget {
  const PlanSheet({
    super.key,
    required this.rows,
    required this.total,
    required this.shown,
    required this.ready,
    required this.errors,
    required this.warnings,
    required this.canApply,
    required this.big,
    required this.peek,
    required this.onShow,
    required this.onUnpeek,
    required this.onApply,
    required this.onReject,
    this.busy = false,
  });

  final List<PlanRow> rows;
  final int total;
  final int shown;
  final bool ready;
  final int errors;
  final int warnings;

  /// Можно ли применить — то же правило, что на экране ассистента (ошибка запирает).
  final bool canApply;
  final bool big;
  final bool peek;
  final ValueChanged<PlanRow> onShow;
  final VoidCallback onUnpeek;
  final VoidCallback onApply;
  final VoidCallback onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final h = MediaQuery.sizeOf(context).height;
    final checkLine = ready
        ? 'Проверка: ошибок $errors, предупреждений $warnings'
        : 'Строю план: $shown из $total';
    return Container(
      key: const Key('holst-plan'),
      decoration: BoxDecoration(
        color: s.surfaceContainerLow,
        border: Border(top: BorderSide(color: s.outline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
            child: Row(
              children: [
                Text(
                  'План',
                  style: TextStyle(
                    fontFamily: AppStyle.of(context).display,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    changesWord(total),
                    key: const Key('holst-plan-title'),
                    style: TextStyle(fontSize: 14, color: s.onSurfaceVariant),
                  ),
                ),
                if (peek)
                  OutlinedButton(
                    key: const Key('holst-plan-list'),
                    onPressed: onUnpeek,
                    child: const Text('Список'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(
                  ready
                      ? (errors > 0
                            ? Symbols.error_rounded
                            : Symbols.check_rounded)
                      : Symbols.auto_awesome_rounded,
                  size: 18,
                  color: errors > 0 ? s.error : s.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    checkLine,
                    key: const Key('holst-plan-check'),
                    style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          if (!peek)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: big ? h * .45 : 112),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final (i, r) in rows.take(shown).indexed)
                    _Row(
                      key: Key('holst-plan-row-$i'),
                      row: r,
                      onShow: big && r.target != null ? () => onShow(r) : null,
                      change: c.change,
                      ok: c.ok,
                    ),
                ],
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: s.outlineVariant)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('holst-plan-reject'),
                      onPressed: busy ? null : onReject,
                      child: const Text('Отклонить'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      key: const Key('holst-plan-apply'),
                      onPressed: busy || !ready || !canApply ? null : onApply,
                      child: const Text('Применить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.row,
    required this.onShow,
    required this.change,
    required this.ok,
  });

  final PlanRow row;
  final VoidCallback? onShow;
  final Color change;
  final Color ok;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: s.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Имя и что меняется — раздельно, без точек-разделителей.
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      row.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      row.field,
                      style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
                    ),
                  ],
                ),
                if (row.error != null)
                  Text(
                    row.error!,
                    style: TextStyle(fontSize: 13, color: s.error),
                  )
                else if (row.was.isNotEmpty || row.now.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: row.was,
                          style: TextStyle(color: s.onSurfaceVariant),
                        ),
                        TextSpan(
                          text: '  →  ',
                          style: TextStyle(color: s.outline),
                        ),
                        TextSpan(
                          text: row.now,
                          style: TextStyle(
                            color: row.isNew ? ok : change,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
          if (onShow != null)
            IconButton(
              tooltip: 'Показать на холсте',
              onPressed: onShow,
              icon: const Icon(Symbols.visibility_rounded),
            ),
        ],
      ),
    );
  }
}
