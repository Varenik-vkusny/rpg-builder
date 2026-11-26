// Окно вида А «Лист» (выбор владельца 25.11): шторка снизу одной структуры для всех
// вопросов — значок риска и вопрос → с чем (имя со значком) → последствия строками →
// «Отмена» | главная (шире, справа, ≥ 52 dp). Опасное — красным: без отката красная
// заливка, с откатом красная рамка. Прототип: Docs/rpg-builder/vid-a-prototype.html.
import 'package:flutter/material.dart';

import 'action_sheet_buttons.dart';
import 'theme.dart';

export 'action_sheet_buttons.dart';

/// Риск действия: цвет значка, верхней кромки и главной кнопки.
enum SheetKind {
  /// Необратимое: красный значок, красная кромка, кнопка залита красным.
  danger,

  /// Опасное, но с откатом: тёмно-красный значок, кнопка в красной рамке.
  soft,

  /// Обычное: серый значок, кнопка — голубая главная.
  plain,

  /// Предупреждение: жёлтый значок.
  warn,

  /// Ассистент: голубой значок.
  ai,
}

/// С чем действие: значок вида и имя; [to] — куда (перенос: «› Рынок»).
class SheetSubject {
  const SheetSubject(this.icon, this.name, {this.to});
  final IconData icon;
  final String name;
  final String? to;
}

/// Цвет строки-последствия.
enum FactTone { normal, hot, warn }

/// Последствие строкой со значком. [changed] — что станет, цветом «изменено» после [text].
class SheetFact {
  const SheetFact(
    this.icon,
    this.text, {
    this.tone = FactTone.normal,
    this.changed,
  });
  final IconData icon;
  final String text;
  final FactTone tone;
  final String? changed;
}

/// Шторка-вопрос: true — главное действие, false — «Отмена» или смахнули.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String action,
  SheetKind kind = SheetKind.plain,
  SheetSubject? subject,
  List<SheetFact> facts = const [],
  IconData? actionIcon,
  SheetMain? main,
  String cancel = 'Отмена',
  Key sheetKey = const Key('confirm'),
  Key yesKey = const Key('confirm-yes'),
  Key noKey = const Key('confirm-no'),
}) async =>
    await showActionSheet<bool>(
      context,
      kind: kind,
      builder: (context) => SheetLayout(
        key: sheetKey,
        kind: kind,
        icon: icon,
        title: title,
        subject: subject,
        facts: facts,
        actions: [
          sheetCancel(context, cancel, noKey, false),
          sheetMain(
            context,
            label: action,
            icon: actionIcon,
            style: main ?? _mainFor(kind),
            key: yesKey,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    ) ??
    false;

/// Отказ: та же шторка с одной кнопкой «Понятно» (удалить нельзя — на объект ссылаются).
Future<void> showRefusal(
  BuildContext context, {
  required String title,
  required IconData icon,
  SheetSubject? subject,
  List<SheetFact> facts = const [],
  Key sheetKey = const Key('refusal'),
}) => showActionSheet<void>(
  context,
  kind: SheetKind.danger,
  builder: (context) => SheetLayout(
    key: sheetKey,
    kind: SheetKind.danger,
    icon: icon,
    title: title,
    subject: subject,
    facts: facts,
    actions: [
      sheetMain(
        context,
        label: 'Понятно',
        style: SheetMain.plain,
        key: const Key('refusal-ok'),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  ),
);

SheetMain _mainFor(SheetKind kind) => switch (kind) {
  SheetKind.danger => SheetMain.danger,
  SheetKind.soft => SheetMain.dangerOutline,
  _ => SheetMain.primary,
};

/// Показывает шторку вида А: без скруглений, кромка сверху (у необратимого — красная).
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  SheetKind kind = SheetKind.plain,
}) {
  final s = Theme.of(context).colorScheme;
  final danger = kind == SheetKind.danger;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: s.surfaceContainerHigh,
    barrierColor: const Color(0xB8060709),
    shape: Border(
      top: BorderSide(
        color: danger ? s.error : s.outline,
        width: danger ? 3 : 1,
      ),
    ),
    builder: builder,
  );
}

/// Каркас шторки: ручка, значок и вопрос, тело, ряд кнопок.
class SheetLayout extends StatelessWidget {
  const SheetLayout({
    super.key,
    required this.kind,
    required this.icon,
    required this.title,
    this.subject,
    this.facts = const [],
    this.body = const [],
    required this.actions,
  });

  final SheetKind kind;
  final IconData icon;
  final String title;
  final SheetSubject? subject;
  final List<SheetFact> facts;

  /// Своё содержимое под последствиями (варианты ответа, пункты меню).
  final List<Widget> body;

  /// «Отмена» и главная; одна кнопка — во всю ширину.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final (bg, fg) = switch (kind) {
      SheetKind.danger => (s.error, s.onError),
      SheetKind.soft => (s.errorContainer, s.error),
      SheetKind.plain => (s.surfaceContainerHighest, s.onSurface),
      SheetKind.warn => (c.warn, s.onError),
      SheetKind.ai => (s.primary, s.onPrimary),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Center(child: Container(width: 32, height: 4, color: s.outline)),
            Row(
              spacing: 12,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  color: bg,
                  alignment: Alignment.center,
                  child: Icon(icon, size: 28, color: fg),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontSize: 19, height: 1.2),
                  ),
                ),
              ],
            ),
            if (subject case final subj?) _Subject(subj),
            if (facts.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 2,
                children: [for (final f in facts) _Fact(f)],
              ),
            ...body,
            Row(
              spacing: 8,
              children: [
                for (final (i, a) in actions.indexed)
                  Expanded(
                    flex: actions.length == 1 || i == 0 ? 1 : 2,
                    child: a,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Subject extends StatelessWidget {
  const _Subject(this.subject);
  final SheetSubject subject;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      key: const Key('sheet-subject'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.surfaceContainer,
        border: Border.all(color: s.outlineVariant),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 40,
            height: 40,
            color: s.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(subject.icon, size: 24),
          ),
          Expanded(
            child: Text(
              subject.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
          ),
          if (subject.to case final to?)
            Text(
              '› $to',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: s.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.fact);
  final SheetFact fact;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final (iconColor, color, weight) = switch (fact.tone) {
      FactTone.hot => (s.error, s.error, FontWeight.w600),
      FactTone.warn => (c.warn, s.onSurface, FontWeight.w600),
      FactTone.normal => (s.onSurfaceVariant, s.onSurface, FontWeight.w400),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        spacing: 10,
        children: [
          Icon(fact.icon, size: 20, color: iconColor),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: fact.text,
                children: [
                  if (fact.changed case final ch?)
                    TextSpan(
                      text: ch,
                      style: TextStyle(
                        color: c.change,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              style: TextStyle(fontSize: 15, color: color, fontWeight: weight),
            ),
          ),
        ],
      ),
    );
  }
}
