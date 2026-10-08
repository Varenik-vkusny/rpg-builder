// Сообщения автору, одинаковые на всех экранах: вопрос перед необратимым действием.
import 'package:flutter/material.dart';

/// Спрашивает автора перед действием; «да» — true, «Отмена» и нажатие мимо — false.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String text,
  required String action,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('confirm'),
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            key: const Key('confirm-no'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            key: const Key('confirm-yes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
