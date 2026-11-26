// Правило 11 (VISION §8): жест на холсте — маленький план. Тот же путь, что у формы:
// проверка на копии мира (ошибка — не применяется), набор в историю, откат.
// Исключение одно — положение блока на холсте. Других записей в мир холст не делает:
// прибор test/holst_rule11_test.dart ищет их в lib/map и краснеет.
import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../content/manual_edit.dart';
import '../content/manual_save.dart';
import '../ui/offline.dart';

enum GestureTone { ok, warn, error }

/// Итог жеста: применён (ok / с предупреждением) или нет (error — с причиной).
class GestureResult {
  const GestureResult({
    required this.tone,
    this.reason,
    this.problem,
    this.setId,
    this.warnings = const [],
    this.offline = false,
    this.retry = false,
  });

  /// Не записан из-за сети.
  final bool offline;

  /// Запрос точно не ушёл — «Повторить» безопасно (без двойной записи).
  final bool retry;

  final GestureTone tone;

  /// Почему не применён — одной строкой для полосы внизу.
  final String? reason;

  /// Ошибка проверки, из-за которой жест не применён (null — не из-за проверки).
  final Problem? problem;

  /// Набор в истории — его откатывает «Отменить» и «Откатить».
  final String? setId;

  /// Новые предупреждения, появившиеся от жеста: жёлтая метка на объекте.
  final List<Problem> warnings;

  bool get applied => tone != GestureTone.error;
}

/// Единственная дорога жеста в мир.
Future<GestureResult> applyGesture(
  ContentRepo repo,
  String worldId,
  WorldSnapshot world,
  ManualEdit edit,
) async {
  final added = newProblems(world, edit.applyTo(world));
  final errors = [
    for (final p in added)
      if (p.severity == Severity.error) p,
  ];
  if (errors.isNotEmpty) {
    return GestureResult(
      tone: GestureTone.error,
      reason: errors.first.message,
      problem: errors.first,
    );
  }
  try {
    await repo.applyManualEdit(worldId, edit);
  } catch (e) {
    return GestureResult(
      tone: GestureTone.error,
      reason: neverSent(e)
          ? 'жест не записан'
          : isOffline(e)
          ? 'связь оборвалась — проверь историю'
          : 'не сохранено — попробуй ещё раз',
      offline: isOffline(e),
      retry: neverSent(e),
    );
  }
  final history = await repo.history(worldId);
  final warnings = [
    for (final p in added)
      if (p.severity == Severity.warning) p,
  ];
  return GestureResult(
    tone: warnings.isEmpty ? GestureTone.ok : GestureTone.warn,
    setId: history.isEmpty ? null : history.first.id,
    warnings: warnings,
  );
}

/// «Отменить» и «Откатить»: откат набора жеста — тот же откат, что в истории.
/// null — откачено; иначе — почему нельзя.
Future<String?> undoGesture(
  ContentRepo repo,
  String worldId,
  String setId,
) async {
  try {
    if ((await repo.revertConflicts(worldId, setId)).isNotEmpty) {
      return 'мир уже меняли после жеста';
    }
    await repo.revertChangeSet(worldId, setId);
    return null;
  } catch (_) {
    return 'не откачено — проверь связь';
  }
}
