// Кнопка «Экспорт»: проверка мира → при ошибках предупреждение → файл JSON в «Поделиться».
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../check/world_check.dart';
import '../worlds/world.dart';
import 'world_export.dart';

/// Экспортирует [snapshot] мира [world] и открывает системное «Поделиться».
/// Ошибки проверки не запрещают экспорт (файл — не запись мира), но автор видит их до отправки.
Future<void> exportAndShare(
  BuildContext context,
  World world,
  WorldSnapshot snapshot,
) async {
  final errors = checkWorld(snapshot)
      .where((p) => p.severity == Severity.error)
      .toList();
  final messenger = ScaffoldMessenger.of(context);
  if (errors.isNotEmpty && !await _confirmErrors(context, errors)) return;
  final name = exportFileName(world);
  final bytes = utf8.encode(exportJson(world, snapshot));
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/json', name: name),
        ],
        fileNameOverrides: [name],
        subject: world.title,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Не удалось поделиться: $e')),
    );
  }
}

Future<bool> _confirmErrors(BuildContext context, List<Problem> errors) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('export-errors'),
        title: const Text('В мире есть ошибки'),
        content: Text(
          [
            'Ошибок в мире: ${errors.length}. Игра может споткнуться о них.',
            for (final e in errors.take(3)) '• ${e.message}',
            if (errors.length > 3) '…и ещё ${errors.length - 3}',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            key: const Key('export-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            key: const Key('export-anyway'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Всё равно экспортировать'),
          ),
        ],
      ),
    ) ??
    false;
