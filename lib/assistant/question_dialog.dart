// Окно «Ассистент уточняет» — шторка вида А (25.11): вопрос коротко, варианты рядами,
// совет отмечен плашкой «советую», «Свой вариант» с полем; «Отмена» | «Ответить».
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/action_sheet.dart';
import 'assistant_service.dart';

/// Вопрос и варианты (первый — совет ассистента) и «Свой вариант».
/// Возвращает ответ автора или null, если он закрыл окно.
Future<String?> askAuthor(BuildContext context, AuthorQuestion q) =>
    showActionSheet<String>(
      context,
      kind: SheetKind.ai,
      builder: (_) => _QuestionSheet(q),
    );

class _QuestionSheet extends StatefulWidget {
  const _QuestionSheet(this.q);
  final AuthorQuestion q;

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  /// Номер выбранного варианта; равен числу вариантов — «Свой вариант».
  int _choice = 0;
  final _own = TextEditingController();

  bool get _isOwn => _choice == widget.q.options.length;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  String? get _answer {
    if (!_isOwn) return widget.q.options[_choice].label;
    final text = _own.text.trim();
    return text.isEmpty ? null : text;
  }

  Widget _option(int i, String label, {bool advice = false}) {
    final s = Theme.of(context).colorScheme;
    final on = _choice == i;
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        key: Key('question-option-$i'),
        onTap: () => setState(() => _choice = i),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: s.surfaceContainer,
            border: Border.all(color: on ? s.onSurface : s.outlineVariant),
          ),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: on ? s.onSurface : s.outline,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: on
                    ? Container(width: 10, height: 10, color: s.onSurface)
                    : null,
              ),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (advice)
                Container(
                  key: const Key('question-advice'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  color: s.primary,
                  child: Text(
                    'СОВЕТУЮ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .6,
                      color: s.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    return SheetLayout(
      key: const Key('question-dialog'),
      kind: SheetKind.ai,
      icon: Symbols.auto_awesome_rounded,
      title: 'Уточнение',
      body: [
        Text(
          q.question,
          key: const Key('question-text'),
          style: const TextStyle(fontSize: 16, height: 1.35),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            for (final (i, o) in q.options.indexed)
              _option(i, o.label, advice: i == 0),
            _option(q.options.length, 'Свой вариант'),
            if (_isOwn)
              TextField(
                key: const Key('question-own'),
                controller: _own,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Как сделать'),
              ),
          ],
        ),
      ],
      actions: [
        sheetCancel(context, 'Отмена', const Key('question-cancel'), null),
        sheetMain(
          context,
          label: 'Ответить',
          icon: Symbols.check_rounded,
          style: SheetMain.primary,
          key: const Key('question-answer'),
          onPressed: _answer == null
              ? null
              : () => Navigator.of(context).pop(_answer),
        ),
      ],
    );
  }
}
