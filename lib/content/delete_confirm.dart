// Вопрос перед удалением объекта из формы правки.
import 'package:flutter/material.dart';

import '../check/world_check.dart';
import '../ui/messages.dart';
import 'manual_edit.dart';

/// true — удалять. Если на объект ссылаются, вопроса нет: удаление всё равно будет
/// отклонено с причиной, спрашивать о невозможном незачем.
Future<bool> confirmDelete(
  BuildContext context,
  WorldSnapshot world,
  String id,
  String title,
) async {
  if (referencesTo(world, id).isNotEmpty) return true;
  return confirmAction(
    context,
    title: 'Удалить «$title»?',
    text:
        'Объект исчезнет из мира. Удаление можно откатить в истории изменений.',
    action: 'Удалить',
  );
}
