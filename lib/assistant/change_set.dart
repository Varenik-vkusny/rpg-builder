import 'assistant_flow.dart';
import 'assistant_service.dart';
import 'plan.dart';

/// Набор изменений для записи: план целиком, откуда он и сколько стоил.
/// Импорт образца (4.6) — набор без области и без модели: область «import», журнала модели нет.
/// «Применить» пишет его одной транзакцией, «Отклонить» — только в журнал.
class ChangeSetDraft {
  const ChangeSetDraft({
    required this.scope,
    required this.request,
    required this.plan,
    required this.inputTokens,
    required this.outputTokens,
    required int this.attempts,
  }) : importSlug = null;

  /// Импорт образца [slug] из библиотеки: модель не звали — ни токенов, ни попыток.
  const ChangeSetDraft.imported({
    required this.request,
    required this.plan,
    required String slug,
  }) : scope = null,
       importSlug = slug,
       inputTokens = 0,
       outputTokens = 0,
       attempts = null;

  factory ChangeSetDraft.fromRun(PlanRun run, ProposeRequest request) =>
      ChangeSetDraft(
        scope: request.scope,
        request: request.request,
        plan: run.proposal.plan,
        inputTokens: run.inputTokens,
        outputTokens: run.outputTokens,
        attempts: run.attempts,
      );

  /// null — импорт: тогда в журнале область «import» и slug созданного предмета.
  final Scope? scope;
  final String? importSlug;
  final String request;
  final Plan plan;
  final int inputTokens;
  final int outputTokens;

  /// 1 план + исправления, не больше 3 (база тоже не примет больше); null — модель не звали.
  final int? attempts;

  /// Параметры функций базы apply_change_set / reject_change_set.
  Map<String, dynamic> toParams(String worldId) => {
    'p_project_id': worldId,
    'p_scope_type': scope?.type.name ?? 'import',
    'p_scope_slug': scope?.slug ?? importSlug,
    'p_request': request,
    'p_summary': plan.summary,
    'p_ops': plan.toJson()['ops'],
    'p_input_tokens': inputTokens,
    'p_output_tokens': outputTokens,
    'p_attempts': attempts,
  };
}
