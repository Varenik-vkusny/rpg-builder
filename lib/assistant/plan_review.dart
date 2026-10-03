// Просмотр плана по одной операции: свайп, полоска «2 из 5», проблемные — цветом и значком.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import 'plan_cards.dart';
import 'plan_preview.dart';

class PlanReviewScreen extends StatefulWidget {
  const PlanReviewScreen({super.key, required this.preview});
  final PlanPreview preview;

  @override
  State<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  final _pages = PageController();
  int _at = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _bad(int i) =>
      widget.preview.ops[i].error != null ||
      widget.preview.outside.containsKey(i);

  void _go(int i) => _pages.animateToPage(
    i,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final ops = widget.preview.ops;
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_at + 1} из ${ops.length}'),
        leading: IconButton(
          tooltip: 'К плану',
          icon: const Icon(Symbols.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [HelpAction('plan')],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              spacing: 4,
              children: [
                for (var i = 0; i < ops.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: _bad(i)
                            ? s.error
                            : i <= _at
                            ? s.onSurface
                            : s.surfaceContainerHighest,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: ops.length,
              onPageChanged: (i) => setState(() => _at = i),
              itemBuilder: (_, i) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OpCard(
                  result: ops[i],
                  outside: widget.preview.outside[i],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                spacing: 8,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Предыдущее',
                    onPressed: _at == 0 ? null : () => _go(_at - 1),
                    icon: const Icon(Symbols.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _bad(_at)
                          ? 'Эта операция не пройдёт'
                          : 'Листай влево и вправо',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _bad(_at) ? s.error : s.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Следующее',
                    onPressed: _at == ops.length - 1
                        ? () => Navigator.of(context).pop()
                        : () => _go(_at + 1),
                    icon: Icon(
                      _at == ops.length - 1
                          ? Symbols.done_all_rounded
                          : Symbols.arrow_forward_rounded,
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
