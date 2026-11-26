// Ряд набора истории вида А (25.11): слева ячейка 52 dp цвета действия (+ зелёная,
// ✎ пурпурная, − и ↺ серые), посередине имя крупно и «глагол цветом + поле было →
// стало», справа время над значком источника. «Применён» не пишем — это норма;
// откачен — плашкой, ряд приглушён. Мини-ряд — для «Последних изменений» мира.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/theme.dart';
import 'history.dart';
import 'history_line.dart';
import 'plan_labels.dart' show journalLinkWord;

/// Цвета ячейки действия: фон и значок.
(Color, Color) verbColors(BuildContext context, Verb v) {
  final s = Theme.of(context).colorScheme;
  final c = AppColors.of(context);
  return switch (v) {
    Verb.created => (c.okContainer, c.ok),
    Verb.changed => (c.changeContainer, c.change),
    _ => (s.surfaceContainerHighest, s.onSurface),
  };
}

/// Цвет глагола под именем.
Color verbColor(BuildContext context, Verb v) {
  final c = AppColors.of(context);
  return switch (v) {
    Verb.created => c.ok,
    Verb.changed => c.change,
    _ => Theme.of(context).colorScheme.onSurface,
  };
}

/// «14:40» — время цифрами.
String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Заголовок дня: «Сегодня», «Вчера», «22 ноября».
String dayTitle(DateTime t, DateTime now) {
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  const months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', //
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  final year = t.year == now.year ? '' : ' ${t.year}';
  return '${t.day} ${months[t.month - 1]}$year';
}

/// Голова набора: ячейка действия, имя и что сделано, время и источник.
class HistoryHead extends StatelessWidget {
  const HistoryHead(this.line, this.at, {super.key, this.mini = false});

  final HistoryLine line;
  final DateTime at;

  /// Мини-ряд «Последних изменений»: ниже и мельче, без «было».
  final bool mini;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (bg, fg) = verbColors(context, line.verb);
    final dim = line.off ? .5 : 1.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: dim,
            child: Container(
              width: mini ? 44 : 52,
              constraints: BoxConstraints(minHeight: mini ? 52 : 64),
              color: bg,
              alignment: Alignment.center,
              child: Icon(verbIcon(line.verb), size: mini ? 22 : 26, color: fg),
            ),
          ),
          Expanded(
            child: Padding(
              padding: mini
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: mini ? 0 : 4,
                children: [
                  Opacity(opacity: dim, child: _name(context)),
                  _what(context),
                ],
              ),
            ),
          ),
          _meta(context, s),
        ],
      ),
    );
  }

  Widget _name(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (line.kind case final k?)
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 2),
            child: Icon(k, size: mini ? 16 : 18, color: s.onSurfaceVariant),
          ),
        Flexible(
          child: Text(
            line.name,
            key: const Key('history-name'),
            maxLines: mini ? 1 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: mini ? 15 : 17,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _what(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final size = mini ? 13.0 : 14.0;
    final verb = line.verb == Verb.reverted
        ? 'Откат: ${line.what ?? 'правка'}'
        : verbWord(line.verb);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Opacity(
          opacity: line.off ? .5 : 1,
          child: Text(
            verb,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w600,
              color: verbColor(context, line.verb),
            ),
          ),
        ),
        if (line.field != null)
          Opacity(
            opacity: line.off ? .5 : 1,
            child: Text.rich(
              TextSpan(
                text: mini
                    ? '${line.field} '
                    : '${line.field} ${line.was ?? '—'} → ',
                children: [
                  TextSpan(
                    text: line.now ?? '—',
                    style: TextStyle(
                      color: c.change,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: size, color: s.onSurfaceVariant),
            ),
          ),
        for (final MapEntry(key: v, value: n) in line.tally.entries)
          _Tally(v, n),
        if (line.offWord case final word?)
          Container(
            key: const Key('history-off'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: s.outline)),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .8,
                color: s.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _meta(BuildContext context, ColorScheme s) {
    final time = Text(
      clock(at),
      style: TextStyle(
        fontSize: mini ? 13 : 14,
        fontWeight: FontWeight.w500,
        color: s.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final src = Tooltip(
      message: sourceWord(line.source),
      child: Icon(
        sourceIcon(line.source),
        key: Key('history-source-${line.source.name}'),
        size: mini ? 18 : 20,
        color: s.onSurfaceVariant,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: mini
          ? Row(spacing: 6, children: [src, time])
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 6,
              children: [time, src],
            ),
    );
  }
}

/// Счётчик операций набора ассистента: «＋1», «✎2», «−1».
class _Tally extends StatelessWidget {
  const _Tally(this.verb, this.n);
  final Verb verb;
  final int n;

  @override
  Widget build(BuildContext context) {
    final color = verbColor(context, verb);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Icon(verbIcon(verb), size: 16, color: color),
          Text(
            '$n',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Операция набора: ячейка цвета действия, имя жирным, поле и «было → стало».
class OpRow extends StatelessWidget {
  const OpRow(this.op, this.show, {super.key});
  final JournalOp op;
  final ShowValue show;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    // Каждое значение короче по отдельности: «стало» видно всегда (ревью 22.11).
    String short(String? v) =>
        v == null ? '—' : (v.length > 32 ? '${v.substring(0, 31)}…' : v);
    final link = journalLinkWord(op.type);
    final what = link == null ? op.title : '$link ${op.title}';
    final verb = switch (op.action) {
      'create' => Verb.created,
      'delete' => Verb.deleted,
      _ => Verb.changed,
    };
    final (bg, fg) = verbColors(context, verb);
    return Padding(
      key: Key('history-op-${op.label}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Container(
            width: 24,
            height: 24,
            color: bg,
            alignment: Alignment.center,
            child: Icon(verbIcon(verb), size: 18, color: fg),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: what,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  // Поля — только у правки: созданное и убранное — одним именем.
                  for (final (i, (k, was, now))
                      in (op.action == 'update' ? op.changes : const [])
                          .indexed) ...[
                    TextSpan(
                      text: '${i == 0 ? ' ' : '\n'}${fieldWord(k)}\n',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    TextSpan(text: '${short(show(op, k, was))} → '),
                    TextSpan(
                      text: short(show(op, k, now)),
                      style: TextStyle(
                        color: c.change,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              style: const TextStyle(fontSize: 15, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Раскрытый набор: «Откатить» (и причины, почему нельзя), просьба автора ассистенту,
/// операции ячейками цвета действия.
class SetBody extends StatelessWidget {
  const SetBody({
    super.key,
    required this.top,
    required this.request,
    required this.ops,
    required this.show,
  });

  final List<Widget> top;
  final String? request;
  final List<JournalOp> ops;
  final ShowValue show;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...top,
          if (request case final r?)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Icon(
                    Symbols.chat_bubble_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      '«$r»',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          for (final op in ops) OpRow(op, show),
        ],
      ),
    );
  }
}
