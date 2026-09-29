import 'dart:convert';
import 'dart:typed_data';

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

/// Ответ автора на вопрос ассистента.
class Answer {
  const Answer(this.question, this.answer);
  final String question;
  final String answer;
}

/// Вопрос ассистента: просьба спорит с правилами мира или неоднозначна.
/// Первый вариант — тот, что ассистент советует; свой ответ автор может вписать всегда.
class AuthorQuestion {
  const AuthorQuestion(this.question, this.options);
  final String question;
  final List<({String label, String description})> options;

  factory AuthorQuestion.fromJson(Map<String, dynamic> j) =>
      AuthorQuestion(j['question'] as String, [
        for (final o in j['options'] as List)
          (
            label: (o as Map)['label'] as String,
            description: o['description'] as String,
          ),
      ]);
}

/// Ассистент не составит план, пока автор не ответит на [question].
class QuestionAsked implements Exception {
  const QuestionAsked(this.question);
  final AuthorQuestion question;
  @override
  String toString() => 'Ассистент спрашивает: ${question.question}';
}

/// Фото скетча к просьбе (4.4): байты и тип картинки. В журнал не пишется — только в запрос.
class SketchImage {
  const SketchImage(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

/// Просьба к ассистенту. [attempt] 0 — первая; 1–2 — исправление [previous]
/// по списку [problems] проверки на копии. [answers] — ответы автора на вопросы ассистента.
class ProposeRequest {
  const ProposeRequest({
    required this.worldId,
    required this.scope,
    required this.request,
    this.attempt = 0,
    this.previous,
    this.problems = const [],
    this.answers = const [],
    this.image,
  });

  final String worldId;
  final Scope scope;
  final String request;
  final int attempt;
  final Plan? previous;
  final List<String> problems;
  final List<Answer> answers;

  /// Скетч: сервер отдаст просьбу модели, которая видит картинки.
  final SketchImage? image;

  Map<String, dynamic> toJson() => {
    'project_id': worldId,
    'scope': {'type': scope.type.name, 'slug': scope.slug},
    'request': request,
    'attempt': attempt,
    'previous_plan': previous?.toJson(),
    'problems': problems,
    'answers': [
      for (final a in answers) {'question': a.question, 'answer': a.answer},
    ],
    if (image case final i?)
      'image': {'mime': i.mime, 'data': base64Encode(i.bytes)},
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
  /// План или [QuestionAsked], если ассистенту нужен ответ автора.
  Future<Proposal> propose(ProposeRequest request);
}

class SupabaseAssistantService implements AssistantService {
  SupabaseAssistantService(this._client, {this.model});
  final SupabaseClient _client;

  /// Только для сравнения моделей живыми прогонами (live/): «провайдер:модель» из списка
  /// функции (providers.ts). Приложение не задаёт — модель выбирает сервер.
  final String? model;

  @override
  Future<Proposal> propose(ProposeRequest request) async {
    try {
      final res = await _client.functions.invoke(
        'assistant',
        body: {...request.toJson(), 'model': ?model},
      );
      final body = res.data as Map<String, dynamic>;
      if (body['question'] case final Map<String, dynamic> q) {
        throw QuestionAsked(AuthorQuestion.fromJson(q));
      }
      final usage = body['usage'] as Map<String, dynamic>? ?? const {};
      return Proposal(
        Plan.fromJson(body['plan'] as Map<String, dynamic>),
        inputTokens: usage['input_tokens'] as int? ?? 0,
        outputTokens: usage['output_tokens'] as int? ?? 0,
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final text = details is Map ? details['error'] : details;
      // Что именно вышло за область — автору видно, о чём переспросить.
      final outside = details is Map ? details['out_of_scope'] : null;
      final why = outside is List ? ': ${outside.join('; ')}' : '';
      throw AssistantException('Ассистент не ответил: ${text ?? e.status}$why');
    }
  }
}
