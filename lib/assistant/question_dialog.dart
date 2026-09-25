import 'package:flutter/material.dart';

import 'assistant_service.dart';

/// Окно «Ассистент уточняет»: вопрос, варианты с пояснением (первый — совет ассистента)
/// и «Свой вариант». Возвращает ответ автора или null, если он закрыл окно.
Future<String?> askAuthor(BuildContext context, AuthorQuestion q) =>
    showDialog<String>(context: context, builder: (_) => _QuestionDialog(q));

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog(this.q);
  final AuthorQuestion q;

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
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

  Widget _option(int i, String label, Widget? subtitle) => RadioListTile<int>(
    key: Key('question-option-$i'),
    value: i,
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: subtitle,
  );

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    return AlertDialog(
      key: const Key('question-dialog'),
      title: const Text('Ассистент уточняет'),
      content: SingleChildScrollView(
        child: RadioGroup<int>(
          groupValue: _choice,
          onChanged: (v) => setState(() => _choice = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(q.question, key: const Key('question-text')),
              const SizedBox(height: 8),
              for (final (i, o) in q.options.indexed)
                _option(
                  i,
                  i == 0 ? '${o.label} (советую)' : o.label,
                  Text(o.description),
                ),
              _option(
                q.options.length,
                'Свой вариант',
                _isOwn
                    ? TextField(
                        key: const Key('question-own'),
                        controller: _own,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Как сделать',
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('question-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('question-answer'),
          onPressed: _answer == null
              ? null
              : () => Navigator.of(context).pop(_answer),
          child: const Text('Ответить'),
        ),
      ],
    );
  }
}
