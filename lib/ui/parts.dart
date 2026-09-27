// Общие детали интерфейса: метка изменения, плашка, «Было / Стало».
// Смысл никогда не передаётся одним цветом — всегда значок и слово.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'theme.dart';

enum Change {
  create('новое', Symbols.add_rounded),
  update('изменено', Symbols.edit_rounded),
  delete('убрано', Symbols.remove_rounded);

  const Change(this.word, this.icon);
  final String word;
  final IconData icon;
}

/// «＋ новое», «✎ изменено», «− убрано».
class ChangeTag extends StatelessWidget {
  const ChangeTag(this.change, {super.key});
  final Change change;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final (bg, fg) = switch (change) {
      Change.create => (c.okContainer, c.onOkContainer),
      Change.update => (s.primaryContainer, s.onPrimaryContainer),
      Change.delete => (s.errorContainer, s.onErrorContainer),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(change.icon, size: 15, color: fg, weight: 600),
          Text(
            change.word,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum Notice {
  error('Ошибка', Symbols.error_rounded),
  warning('Предупреждение', Symbols.warning_rounded),
  fix('Поправлено сервером', Symbols.build_rounded);

  const Notice(this.word, this.icon);
  final String word;
  final IconData icon;
}

/// Плашка с заголовком-словом и значком: ошибка, предупреждение, правка сервера.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.notice, this.text, {super.key, this.title});
  final Notice notice;
  final String text;

  /// Заголовок вместо слова по умолчанию («Ошибка — блокирует план»).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final (bg, fg) = switch (notice) {
      Notice.error => (s.errorContainer, s.onErrorContainer),
      Notice.warning => (c.warnContainer, c.onWarnContainer),
      Notice.fix => (s.surfaceContainerHighest, s.onSurface),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(notice.icon, size: 20, color: fg, fill: 1),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${title ?? notice.word}\n',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: TextStyle(color: fg, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Поле плана: подпись, «БЫЛО», стрелка, «СТАЛО». Нет старого — «НОВОЕ»; нет нового — «убрано».
class BeforeAfter extends StatelessWidget {
  const BeforeAfter({
    super.key,
    required this.label,
    required this.before,
    required this.after,
    this.icon,
  });

  final String label;
  final String? before;
  final String? after;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(
              icon ?? Symbols.notes_rounded,
              size: 18,
              color: s.onSurfaceVariant,
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: s.onSurfaceVariant, fontSize: 14),
              ),
            ),
          ],
        ),
        if (before case final b?) ...[
          _Side(
            'БЫЛО',
            b.isEmpty ? 'пусто' : b,
            s.surfaceContainerLow,
            s.onSurfaceVariant,
          ),
          Icon(
            Symbols.arrow_downward_rounded,
            size: 16,
            color: s.onSurfaceVariant,
          ),
        ],
        switch (after) {
          null => _Side(
            'СТАЛО',
            'убрано',
            s.errorContainer,
            s.onErrorContainer,
          ),
          final a => _Side(
            before == null ? 'НОВОЕ' : 'СТАЛО',
            a.isEmpty ? 'пусто' : a,
            s.primaryContainer,
            s.onPrimaryContainer,
          ),
        },
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side(this.word, this.value, this.bg, this.fg);
  final String word;
  final String value;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            word,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: .4,
              height: 1.8,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: TextStyle(color: fg, fontSize: 15)),
        ),
      ],
    ),
  );
}
