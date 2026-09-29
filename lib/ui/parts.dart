// Общие детали интерфейса: метка изменения, плашка, «Было / Стало», значок объекта.
// Смысл никогда не передаётся одним цветом — всегда значок и слово.
// Стиль телетекста: деталь — ячейка с цветной рамкой, цветное слово, текст светлый.
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
    final c = AppColors.of(context);
    final line = switch (change) {
      Change.create => c.ok,
      Change.update => c.change,
      Change.delete => Theme.of(context).colorScheme.error,
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: line)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(change.icon, size: 15, color: line, weight: 600),
          Text(
            change.word,
            style: TextStyle(
              color: line,
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
    final line = switch (notice) {
      Notice.error => s.error,
      Notice.warning => AppColors.of(context).warn,
      Notice.fix => s.outline,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(border: Border.all(color: line)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Icon(notice.icon, size: 20, color: line, fill: 1),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: s.onSurface, fontSize: 14, height: 1.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? notice.word,
                    style: TextStyle(fontWeight: FontWeight.w500, color: line),
                  ),
                  Text(text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Поле плана: подпись, «БЫЛО», стрелка, «СТАЛО». Нет старого — одна строка «поле · значение»;
/// нет нового — «СТАЛО: убрано».
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
    final head = Row(
      spacing: 8,
      children: [
        Icon(
          icon ?? Symbols.notes_rounded,
          size: 18,
          color: s.onSurfaceVariant,
        ),
        // Подпись поля — всегда целым словом; сжимается значение, а не подпись.
        if (before == null && after != null) ...[
          Text(
            label,
            style: TextStyle(color: s.onSurfaceVariant, fontSize: 14),
          ),
          // Новое значение без старого — одной строкой: сравнивать не с чем.
          Expanded(
            child: Text(
              after!.isEmpty ? 'пусто' : after!,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ] else
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: s.onSurfaceVariant, fontSize: 14),
            ),
          ),
      ],
    );
    if (before == null && after != null) return head;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        head,
        if (before case final b?) ...[
          _Side('БЫЛО', b.isEmpty ? 'пусто' : b, s.outline),
          Icon(
            Symbols.arrow_downward_rounded,
            size: 16,
            color: s.onSurfaceVariant,
          ),
        ],
        switch (after) {
          null => _Side('СТАЛО', 'убрано', s.error),
          final a => _Side(
            'СТАЛО',
            a.isEmpty ? 'пусто' : a,
            AppColors.of(context).change,
          ),
        },
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side(this.word, this.value, this.line);
  final String word;
  final String value;

  /// Цвет рамки и слова: «БЫЛО» — серый, «СТАЛО» — пурпурный, «убрано» — красный.
  final Color line;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(border: Border.all(color: line)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            word,
            style: TextStyle(
              color: line,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: .4,
              height: 1.8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Значок объекта в квадратной ячейке.
class Avatar extends StatelessWidget {
  const Avatar(this.icon, {super.key, required this.size});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: Border.all(color: s.outlineVariant)),
      child: Icon(icon, size: size * .54, color: s.onSurfaceVariant),
    );
  }
}

/// Главное действие экрана — полоса внизу во всю ширину. В отличие от плавающей
/// кнопки, она ничего не закрывает: список кончается над ней.
class BottomAction extends StatelessWidget {
  const BottomAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface,
        border: Border(top: BorderSide(color: s.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Строка-ссылка на связанный объект: значок, текст, стрелка; нажатие — страница объекта.
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          spacing: 12,
          children: [
            Icon(icon, size: 20, color: s.onSurfaceVariant),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            Icon(
              Symbols.chevron_right_rounded,
              size: 20,
              color: s.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
