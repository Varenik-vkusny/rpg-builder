import 'package:supabase/supabase.dart';

import 'plan.dart';

/// Что автор выбирает областью правки.
enum ScopeType {
  location('Локация'),
  quest('Квест'),
  character('Персонаж');

  const ScopeType(this.label);
  final String label;
}

/// Область: вид и slug выбранного объекта.
class Scope {
  const Scope(this.type, this.slug);
  final ScopeType type;
  final String slug;
}

/// Просьба к ассистенту. [attempt] 0 — первая; 1–2 — исправление [previous]
/// по списку [problems] проверки на копии.
class ProposeRequest {
  const ProposeRequest({
    required this.worldId,
    required this.scope,
    required this.request,
    this.attempt = 0,
    this.previous,
    this.problems = const [],
  });

  final String worldId;
  final Scope scope;
  final String request;
  final int attempt;
  final Plan? previous;
  final List<String> problems;

  Map<String, dynamic> toJson() => {
    'project_id': worldId,
    'scope': {'type': scope.type.name, 'slug': scope.slug},
    'request': request,
    'attempt': attempt,
    'previous_plan': previous?.toJson(),
    'problems': problems,
  };
}

/// План и сколько токенов на него ушло.
class Proposal {
  const Proposal(this.plan, {this.inputTokens = 0, this.outputTokens = 0});
  final Plan plan;
  final int inputTokens;
  final int outputTokens;
}

/// Ассистент ответил ошибкой — текст для автора.
class AssistantException implements Exception {
  const AssistantException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ассистент правок. Ключа API в приложении нет — только серверная функция.
abstract class AssistantService {
  Future<Proposal> propose(ProposeRequest request);
}

class SupabaseAssistantService implements AssistantService {
  SupabaseAssistantService(this._client);
  final SupabaseClient _client;

  @override
  Future<Proposal> propose(ProposeRequest request) async {
    try {
      final res = await _client.functions.invoke(
        'assistant',
        body: request.toJson(),
      );
      final body = res.data as Map<String, dynamic>;
      final usage = body['usage'] as Map<String, dynamic>? ?? const {};
      return Proposal(
        Plan.fromJson(body['plan'] as Map<String, dynamic>),
        inputTokens: usage['input_tokens'] as int? ?? 0,
        outputTokens: usage['output_tokens'] as int? ?? 0,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final text = details is Map ? details['error'] : details;
      throw AssistantException('Ассистент не ответил: ${text ?? e.status}');
    }
  }
}
