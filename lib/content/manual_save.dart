// Сохранение правки и удаление вручную (4.1): сначала те же правила на копии мира
// (правило 4 — мир с ошибкой не сохраняется), потом одной транзакцией в историю.
import '../check/world_check.dart';
import 'content_repo.dart';
import 'manual_edit.dart';

String _key(Problem p) => '${p.rule}|${p.objectId}|${p.message}';

/// null — сохранено (или менять было нечего); иначе — что сказать автору.
Future<String?> saveManualEdit(
  ContentRepo repo,
  String worldId,
  WorldSnapshot world,
  ManualEdit edit,
) async {
  if (edit.isEmpty) return null;
  final was = {for (final p in checkWorld(world)) _key(p)};
  final broken = [
    for (final p in checkWorld(edit.applyTo(world)))
      if (p.severity == Severity.error && !was.contains(_key(p))) p.message,
  ];
  if (broken.isNotEmpty) {
    return 'Правка ломает мир — не сохранено: ${broken.join('; ')}';
  }
  try {
    await repo.applyManualEdit(worldId, edit);
    return null;
  } catch (e) {
    return 'Не удалось сохранить — в мире ничего не изменилось: $e';
  }
}

/// Удаление: на объект ссылаются — нельзя (сначала убери ссылки). Своя добыча врага,
/// свои шаги и награды квеста уходят вместе с ним и возвращаются откатом.
Future<String?> deleteManually(
  ContentRepo repo,
  String worldId,
  WorldSnapshot world, {
  required String type,
  required String id,
  required String slug,
  required String title,
}) async {
  final refs = referencesTo(world, id);
  if (refs.isNotEmpty) {
    return 'Нельзя удалить «$title» — на него ссылаются: ${refs.join('; ')}';
  }
  try {
    await repo.applyManualEdit(
      worldId,
      deleteObject(worldId, type: type, id: id, slug: slug, title: title),
    );
    return null;
  } catch (e) {
    return 'Не удалось удалить — в мире ничего не изменилось: $e';
  }
}
