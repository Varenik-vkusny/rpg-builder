// «Назад» из формы, где автор что-то ввёл, спрашивает, бросить ли введённое
// (телефон 22.11: всё пропадало молча). Сохранение и удаление закрывают форму сами
// (Navigator.pop) — вопроса нет; спрашивают только стрелка «назад» и кнопка телефона.
import 'package:flutter/material.dart';

import 'messages.dart';

mixin DiscardGuard<T extends StatefulWidget> on State<T> {
  String? _start;

  /// Всё, что автор вводит в форме: поля, выборы, строки списков.
  List<Object?> get formValues;

  String get _signature =>
      [for (final v in formValues) v is TextEditingController ? v.text : '$v']
          .join('\u0001');

  bool get formDirty => _start != null && _signature != _start;

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
      final leave =
          !formDirty ||
          await confirmAction(
            context,
            title: 'Бросить введённое?',
            text: 'Изменения не сохранятся.',
            action: 'Бросить',
          );
      if (leave && mounted) Navigator.of(context).pop();
    },
    child: child,
  );
}
