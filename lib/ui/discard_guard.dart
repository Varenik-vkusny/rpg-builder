// «Назад» из формы, где автор что-то ввёл, спрашивает, бросить ли введённое
// (телефон 22.11: всё пропадало молча). Сохранение и удаление закрывают форму сами
// (Navigator.pop) — вопроса нет; спрашивают только стрелка «назад» и кнопка телефона.
// Вид А (25.11): шторка показывает, что пропадёт, — имя и изменённые поля.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'messages.dart';

mixin DiscardGuard<T extends StatefulWidget> on State<T> {
  Map<String, String>? _start;

  /// Всё, что автор вводит в форме, под подписью поля: поля, выборы, строки списков.
  Map<String, Object?> get formFields;

  /// Значок вида объекта — в шторке рядом с именем.
  IconData get formIcon;

  static String _text(Object? v) => switch (v) {
    TextEditingController c => c.text,
    Iterable<Object?> list => [for (final x in list) _text(x)].join('\u0002'),
    _ => '$v',
  };

  Map<String, String> get _signature => {
    for (final MapEntry(:key, :value) in formFields.entries) key: _text(value),
  };

  /// Подписи полей, которые автор изменил.
  List<String> get changedFields {
    final start = _start;
    if (start == null) return const [];
    return [
      for (final MapEntry(:key, :value) in _signature.entries)
        if (start[key] != value) key,
    ];
  }

  bool get formDirty => changedFields.isNotEmpty;

  /// Имя в шторке: первое текстовое поле формы (название, имя).
  String get _name {
    for (final v in formFields.values) {
      if (v is TextEditingController) return v.text.trim();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    // Начальное — после первого кадра, когда форма правки уже заполнена.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start = _signature;
    });
  }

  Widget guardPop(Widget child) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final changed = changedFields;
      final leave =
          changed.isEmpty ||
          await confirmAction(
            context,
            title: 'Бросить введённое?',
            icon: Symbols.close_rounded,
            kind: SheetKind.soft,
            subject: _name.isEmpty ? null : SheetSubject(formIcon, _name),
            facts: [SheetFact(Symbols.edit_note_rounded, _sentence(changed))],
            action: 'Бросить',
            actionIcon: Symbols.close_rounded,
          );
      if (leave && mounted) Navigator.of(context).pop();
    },
    child: child,
  );

  /// «Название, уровни»: первая подпись с заглавной, остальные строчными.
  static String _sentence(List<String> labels) {
    final s = labels.join(', ').toLowerCase();
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }
}
