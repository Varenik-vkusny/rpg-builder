// Петля ассистента: план → проверка на копии → новые проблемы уходят модели,
// она исправляет план сама, не больше двух раз (VISION.md, раздел 10).
import '../check/world_check.dart';
import 'assistant_service.dart';
import 'plan_preview.dart';

/// Не больше двух исправлений: защита от зацикливания и расходов на API.
/// Совпадает с MAX_FIXES серверной функции.
const maxFixes = 2;

/// Итог петли: последний план, его проверка на копии, попытки и токены.
class PlanRun {
  const PlanRun({
    required this.proposal,
    required this.preview,
    required this.attempts,
    required this.inputTokens,
    required this.outputTokens,
    this.caught = const [],
  });

  final Proposal proposal;
  final PlanPreview preview;

  /// Сколько раз спросили модель: 1 план + исправления.
  final int attempts;
  final int inputTokens;
  final int outputTokens;

  /// Что проверка на копии поймала перед каждым исправлением.
  final List<List<String>> caught;

  int get fixes => attempts - 1;

  /// Ошибка на копии блокирует «Применить» (правило 4); предупреждения — нет.
  bool get canApply => !preview.hasErrors;
}

/// Просит план и, пока на копии есть новые проблемы, — исправление.
/// [onAttempt] сообщает номер попытки (1 — первая), чтобы экран показал ход.
Future<PlanRun> runAssistant({
  required AssistantService assistant,
  required WorldSnapshot world,
  required ProposeRequest request,
  void Function(int attempt)? onAttempt,
}) async {
  var inTokens = 0, outTokens = 0;
  Future<(Proposal, PlanPreview)> ask(ProposeRequest r) async {
    onAttempt?.call(r.attempt + 1);
    final p = await assistant.propose(r);
    inTokens += p.inputTokens;
    outTokens += p.outputTokens;
    return (p, previewPlan(world, p.plan, r.scope));
  }

  var (proposal, preview) = await ask(request);
  var attempt = 0;
  final caught = <List<String>>[];
  while (preview.fresh.isNotEmpty && attempt < maxFixes) {
    attempt++;
    caught.add([for (final p in preview.fresh) p.message]);
    // Исправление — без скетча: план уже есть, картинка не нужна, и модель со зрением
    // (свой суточный лимит) на него не тратится.
    (proposal, preview) = await ask(
      ProposeRequest(
        worldId: request.worldId,
        scope: request.scope,
        request: request.request,
        attempt: attempt,
        previous: proposal.plan,
        problems: caught.last,
        answers: request.answers,
      ),
    );
  }
  return PlanRun(
    proposal: proposal,
    preview: preview,
    attempts: attempt + 1,
    inputTokens: inTokens,
    outputTokens: outTokens,
    caught: caught,
  );
}
