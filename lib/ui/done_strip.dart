// Полоса «Лист» (вид А): графитовый корпус с цветной ячейкой действия слева. Одна на
// «сделано» после формы и на полосу холста после жеста — без копий.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'theme.dart';

/// Какое это было действие: от него — цвет и значок ячейки слева.
enum DoneKind {
  created,
  changed,
  reverted,
  deleted,
  applied,
  rejected,
  warn,
  error,
  info,
}

/// Ячейка действия: (фон, цвет значка, значок). Серые — без своего фона.
(Color, Color, IconData) _cell(BuildContext context, DoneKind kind) {
  final s = Theme.of(context).colorScheme;
  final c = AppColors.of(context);
  const none = Colors.transparent;
  return switch (kind) {
    DoneKind.created => (c.okContainer, c.ok, Symbols.add_rounded),
    DoneKind.changed => (c.changeContainer, c.change, Symbols.edit_rounded),
    DoneKind.reverted => (none, s.onSurface, Symbols.undo_rounded),
    DoneKind.deleted => (none, s.onSurfaceVariant, Symbols.remove_rounded),
    DoneKind.applied => (c.okContainer, c.ok, Symbols.check_rounded),
    DoneKind.rejected => (none, s.onSurfaceVariant, Symbols.close_rounded),
    DoneKind.warn => (
      c.warn,
      s.surfaceContainerLowest,
      Symbols.warning_rounded,
    ),
    DoneKind.error => (s.error, s.onError, Symbols.priority_high_rounded),
    DoneKind.info => (none, s.onSurfaceVariant, Symbols.info_rounded),
  };
}

/// Корпус полосы. [title] — жирно; [sub] — одной строкой мелко (причина отказа);
/// [body] — вместо заголовка (связь рисунком); [action] — справа за чертой;
/// [bottom] — полоска под полосой (таймер).
class DoneStrip extends StatelessWidget {
  const DoneStrip({
    super.key,
    required this.kind,
    this.title,
    this.sub,
    this.body,
    this.action,
    this.bottom,
    this.hideCell = false,
    this.titleKey,
    this.subKey,
  });

  final DoneKind kind;
  final String? title;
  final String? sub;
  final Widget? body;
  final Widget? action;
  final Widget? bottom;
  final bool hideCell;
  final Key? titleKey, subKey;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final err = kind == DoneKind.error;
    final (cellBg, cellFg, icon) = _cell(context, kind);
    final edge = err
        ? s.error
        : kind == DoneKind.warn
        ? AppColors.of(context).warn
        : s.outline;
    return Material(
      color: err ? s.errorContainer : s.surfaceContainerHighest,
      shape: Border.all(color: edge),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!hideCell)
                    Container(
                      key: const Key('done-cell'),
                      width: 48,
                      color: cellBg,
                      child: Icon(icon, color: cellFg, fill: 1, size: 24),
                    ),
                  Expanded(child: _text(context, err)),
                  ?action,
                ],
              ),
            ),
          ),
          if (bottom case final b?)
            Positioned(left: 0, right: 0, bottom: 0, child: b),
        ],
      ),
    );
  }

  Widget _text(BuildContext context, bool err) {
    final s = Theme.of(context).colorScheme;
    final fg = err ? s.onErrorContainer : s.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ?body,
          if (title case final t?)
            Text(
              t,
              key: titleKey,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: fg,
              ),
            ),
          if (sub case final t?)
            Text(
              t,
              key: subKey,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: err ? s.onErrorContainer : s.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
