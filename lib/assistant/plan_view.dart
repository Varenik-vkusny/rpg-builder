import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import 'plan.dart';
import 'plan_cards.dart';
import 'plan_preview.dart';
import 'plan_review.dart';

/// План глазами автора: итог проверки на копии (только если есть проблемы) и карточка
/// на каждую операцию с «было → стало».
class PlanView extends StatelessWidget {
  const PlanView({super.key, required this.plan, required this.preview});

  final Plan plan;
  final PlanPreview preview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _PlanTitle(plan.summary),
        if (preview.problems.isNotEmpty) PlanVerdict(preview: preview),
        Row(
          children: [
            Expanded(
              child: Text(
                'Что изменится · ${preview.ops.length}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton.icon(
              key: const Key('plan-review'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanReviewScreen(preview: preview),
                ),
              ),
              icon: const Icon(Symbols.view_carousel_rounded),
              label: const Text('По одному'),
            ),
          ],
        ),
        for (final (i, r) in preview.ops.indexed)
          OpCard(
            key: Key('plan-op-$i'),
            result: r,
            outside: preview.outside[i],
          ),
      ],
    );
  }
}

String _count(int n, String one, String few, String many) {
  final m = n % 10, h = n % 100;
  final w = m == 1 && h != 11
      ? one
      : m >= 2 && m <= 4 && (h < 12 || h > 14)
      ? few
      : many;
  return '$n $w';
}

/// Плашка проверки: красная при ошибке, тонкая жёлтая при одних предупреждениях.
/// Нажатие — шторка со всеми проблемами.
class PlanVerdict extends StatelessWidget {
  const PlanVerdict({super.key, required this.preview});
  final PlanPreview preview;

  @override
  Widget build(BuildContext context) {
    final e = preview.of(Severity.error).length;
    final w = preview.of(Severity.warning).length;
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final (bg, fg) = e > 0
        ? (s.errorContainer, s.onErrorContainer)
        : (c.warnContainer, c.onWarnContainer);
    final counts = [
      if (e > 0) _count(e, 'ошибка', 'ошибки', 'ошибок'),
      if (w > 0)
        _count(w, 'предупреждение', 'предупреждения', 'предупреждений'),
    ].join(' · ');
    return Material(
      key: const Key('plan-verdict'),
      color: bg,
      borderRadius: BorderRadius.circular(AppStyle.of(context).radiusM),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppStyle.of(context).radiusM),
        onTap: () => showProblems(context, preview.problems),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: e > 0 ? 14 : 10,
          ),
          child: Row(
            spacing: 12,
            children: [
              Icon(
                e > 0 ? Symbols.block_rounded : Symbols.warning_rounded,
                color: fg,
                fill: 1,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e > 0)
                      Text(
                        'Нельзя применить',
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Text(
                      counts,
                      key: const Key('plan-check-summary'),
                      style: TextStyle(color: fg),
                    ),
                    if (preview.outside.isNotEmpty)
                      Text(
                        'Операций вне области: ${preview.outside.length} — '
                        'такой план применить нельзя',
                        key: const Key('plan-out-of-scope'),
                        style: TextStyle(color: fg),
                      ),
                  ],
                ),
              ),
              Icon(Symbols.chevron_right_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Шторка со списком проблем: значок + слово «Ошибка» / «Предупреждение» + текст.
Future<void> showProblems(
  BuildContext context,
  List<Problem> problems, {
  String title = 'Проверка на копии мира',
  List<String> notes = const [],
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          for (final n in notes) Text(n),
          for (final p in problems)
            NoticeBanner(
              p.severity == Severity.error ? Notice.error : Notice.warning,
              p.message,
            ),
        ],
      ),
    ),
  ),
);

/// Заголовок плана: не выше трёх строк, дальше многоточие; нажатие — полный текст.
class _PlanTitle extends StatefulWidget {
  const _PlanTitle(this.text);
  final String text;

  @override
  State<_PlanTitle> createState() => _PlanTitleState();
}

class _PlanTitleState extends State<_PlanTitle> {
  bool _full = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _full = !_full),
    child: Text(
      widget.text,
      key: const Key('plan-summary'),
      maxLines: _full ? null : 3,
      overflow: _full ? null : TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
    ),
  );
}
