// «Применить» и «Отклонить» план фразы — одно место для экрана ассистента и холста:
// применить — одной транзакцией (правило 3), отклонить — только запись в журнал.
import '../content/content_repo.dart';
import '../ui/offline.dart';
import 'assistant_flow.dart';
import 'assistant_service.dart';
import 'change_set.dart';

/// Почему план не записан: слова автору и исходная ошибка (сеть — «Повторить»).
class DecideFailure {
  const DecideFailure(this.message, this.cause);
  final String message;
  final Object cause;

  /// Обрыв сети: план не потерян.
  bool get offline => isOffline(cause);

  /// Запрос точно не ушёл — повтор не запишет дважды.
  bool get safeRetry => neverSent(cause);
}

/// null — записано; иначе — что сказать автору (в мире ничего не изменилось).
Future<DecideFailure?> decidePlan(
  ContentRepo repo,
  String worldId,
  PlanRun run,
  ProposeRequest asked, {
  required bool apply,
}) async {
  final draft = ChangeSetDraft.fromRun(run, asked);
  try {
    apply
        ? await repo.applyChangeSet(worldId, draft)
        : await repo.rejectChangeSet(worldId, draft);
    return null;
  } catch (e) {
    if (neverSent(e)) {
      return DecideFailure('Нет связи — план не потерян, повтори', e);
    }
    if (isOffline(e)) {
      return DecideFailure('Связь оборвалась — проверь историю', e);
    }
    return DecideFailure(
      apply
          ? 'Не удалось применить — в мире ничего не изменилось: $e'
          : 'Не удалось записать отказ: $e',
      e,
    );
  }
}
