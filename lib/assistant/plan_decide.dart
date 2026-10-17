// «Применить» и «Отклонить» план фразы — одно место для экрана ассистента и холста:
// применить — одной транзакцией (правило 3), отклонить — только запись в журнал.
import '../content/content_repo.dart';
import 'assistant_flow.dart';
import 'assistant_service.dart';
import 'change_set.dart';

/// null — записано; иначе — что сказать автору (в мире ничего не изменилось).
Future<String?> decidePlan(
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
    return apply
        ? 'Не удалось применить — в мире ничего не изменилось: $e'
        : 'Не удалось записать отказ: $e';
  }
}
