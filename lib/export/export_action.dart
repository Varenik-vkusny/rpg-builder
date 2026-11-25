// Кнопка «Экспорт»: проверка мира → при ошибках предупреждение → файл JSON в «Поделиться».
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../check/world_check.dart';
import '../ui/messages.dart';
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
  if (errors.isNotEmpty && !await _confirmErrors(context, world, errors)) {
    return;
  }
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

/// Вид А: жёлтая шторка «В мире ошибки», ошибки строками с ❗, «Всё равно».
Future<bool> _confirmErrors(
  BuildContext context,
  World world,
  List<Problem> errors,
) => confirmAction(
  context,
  title: 'В мире ошибки',
  icon: Symbols.ios_share_rounded,
  kind: SheetKind.warn,
  subject: SheetSubject(Symbols.public_rounded, world.title),
  facts: [
    for (final e in errors.take(3))
      SheetFact(Symbols.error_rounded, e.message, tone: FactTone.hot),
    if (errors.length > 3)
      SheetFact(
        Symbols.error_rounded,
        'И ещё ${errors.length - 3}',
        tone: FactTone.hot,
      ),
  ],
  action: 'Всё равно',
  actionIcon: Symbols.ios_share_rounded,
  main: SheetMain.plain,
  sheetKey: const Key('export-errors'),
  yesKey: const Key('export-anyway'),
  noKey: const Key('export-cancel'),
);
