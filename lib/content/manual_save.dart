// Сохранение правки и удаление вручную (4.1): сначала те же правила на копии мира
// (правило 4 — мир с ошибкой не сохраняется), потом одной транзакцией в историю.
import '../check/world_check.dart';
import 'content_repo.dart';
import 'manual_edit.dart';

String _key(Problem p) => '${p.rule}|${p.objectId}|${p.message}';

/// Проблемы, которых не было до правки: одна проверка для формы и жеста на холсте.
List<Problem> newProblems(WorldSnapshot was, WorldSnapshot now) {
  final old = {for (final p in checkWorld(was)) _key(p)};
  return [
    for (final p in checkWorld(now))
      if (!old.contains(_key(p))) p,
  ];
}

/// null — сохранено (или менять было нечего); иначе — что сказать автору.
Future<String?> saveManualEdit(
  ContentRepo repo,
  String worldId,
  WorldSnapshot world,
  ManualEdit edit,
) async {
  if (edit.isEmpty) return null;
  final broken = [
    for (final p in newProblems(world, edit.applyTo(world)))
      if (p.severity == Severity.error) p.message,
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

/// Создание формой (правило 11): свежий снимок мира — для уникального slug и проверки,
/// дальше тот же путь, что у правки: правила на копии, набор в историю.
Future<String?> createManually(
  ContentRepo repo,
  String worldId,
  ManualEdit Function(WorldSnapshot) build,
) async {
  final WorldSnapshot world;
  try {
    world = await repo.snapshot(worldId);
  } catch (e) {
    return 'Не удалось сохранить — в мире ничего не изменилось: $e';
  }
  return saveManualEdit(repo, worldId, world, build(world));
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
