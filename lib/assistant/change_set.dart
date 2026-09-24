import 'assistant_flow.dart';
import 'assistant_service.dart';
import 'plan.dart';

/// Набор изменений для записи: план целиком, откуда он и сколько стоил.
/// «Применить» пишет его одной транзакцией, «Отклонить» — только в журнал.
class ChangeSetDraft {
  const ChangeSetDraft({
    required this.scope,
    required this.request,
    required this.plan,
    required this.inputTokens,
    required this.outputTokens,
    required this.attempts,
  });

  factory ChangeSetDraft.fromRun(PlanRun run, ProposeRequest request) =>
      ChangeSetDraft(
        scope: request.scope,
        request: request.request,
        plan: run.proposal.plan,
        inputTokens: run.inputTokens,
        outputTokens: run.outputTokens,
        attempts: run.attempts,
      );

  final Scope scope;
  final String request;
  final Plan plan;
  final int inputTokens;
  final int outputTokens;

  /// 1 план + исправления, не больше 3 (база тоже не примет больше).
  final int attempts;

  /// Параметры функций базы apply_change_set / reject_change_set.
  Map<String, dynamic> toParams(String worldId) => {
    'p_project_id': worldId,
    'p_scope_type': scope.type.name,
    'p_scope_slug': scope.slug,
    'p_request': request,
    'p_summary': plan.summary,
    'p_ops': plan.toJson()['ops'],
    'p_input_tokens': inputTokens,
    'p_output_tokens': outputTokens,
    'p_attempts': attempts,
  };
}
