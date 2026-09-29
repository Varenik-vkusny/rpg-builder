// ЖИВОЙ ПРОГОН с настоящей моделью через выложенную функцию Supabase «assistant».
// Стоит денег и минут — в check.sh НЕ входит. Запускается руками, один раз на приёмку:
//   bash -c 'set -a; . ./.env.test; flutter test --no-pub live/assistant_live_test.dart'
// Сцена приёмки: «Штольня №3» → «затопи её, слизни там жить не могут» → план →
// проверка на копии → исправления → «Применить» → мир изменился.
// Повтор → «Отклонить» → мир не изменился.
@Tags(['live'])
@Timeout(Duration(minutes: 10))
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_flow.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';

import '../test/assistant_fixtures.dart';
import '../test/db_helpers.dart';

String show(WorldSnapshot w) {
  final t = w.titles;
  return [
    for (final l in w.locations) '  локация ${l.slug}: «${l.description}»',
    for (final c in w.characters)
      '  ${c.role.name} ${c.slug}: ур. ${c.level}, атака ${c.attack}, '
          'в ${t[c.locationId]}, добыча ${c.loot.map((l) => t[l.itemId])}',
    for (final q in w.quests)
      '  квест ${q.slug}: ${q.steps.map((s) => s.label(t[s.targetId] ?? '?'))}',
  ].join('\n');
}

/// Живой ассистент, который на вопрос автору получает первый (рекомендуемый) вариант.
/// Возвращает прогон и заданные вопросы.
Future<(PlanRun, List<AuthorQuestion>)> runAnswering({
  required AssistantService assistant,
  required WorldSnapshot world,
  required ProposeRequest request,
  void Function(int attempt)? onAttempt,
}) async {
  final asked = <AuthorQuestion>[];
  var answers = <Answer>[];
  while (true) {
    try {
      final run = await runAssistant(
        assistant: assistant,
        world: world,
        request: ProposeRequest(
          worldId: request.worldId,
          scope: request.scope,
          request: request.request,
          answers: answers,
          image: request.image,
        ),
        onAttempt: onAttempt,
      );
      return (run, asked);
    } on QuestionAsked catch (q) {
      asked.add(q.question);
      debugPrint('ВОПРОС: ${q.question.question}');
      for (final o in q.question.options) {
        debugPrint('  ○ ${o.label} — ${o.description}');
      }
      final pick = q.question.options.first.label;
      debugPrint('  ОТВЕТ АВТОРА: $pick');
      answers = [...answers, Answer(q.question.question, pick)];
    }
  }
}

void main() {
  test('живой прогон: затопить штольню — применить; повтор — отклонить', () async {
    final a = await testAuthor();
    final repo = SupabaseContentRepo(a);
    final world = await SupabaseWorldsRepo(a).create(
      const NewWorld(
        title: 'Пепельные копи (живой прогон)',
        setting: 'шахтёрский посёлок в пепельных горах',
        tone: 'мрачный',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    addTearDown(() => a.from('projects').delete().eq('id', world.id));
    await fillMines(repo, world.id);
    final assistant = SupabaseAssistantService(a);
    const scope = Scope(ScopeType.location, 'shtolnya_3');
    final ask = ProposeRequest(
      worldId: world.id,
      scope: scope,
      request: 'Затопи её, слизни там жить не могут',
    );

    final before = await repo.snapshot(world.id);
    debugPrint('МИР ДО:\n${show(before)}');
    final sw = Stopwatch()..start();
    final (run, _) = await runAnswering(
      assistant: assistant,
      world: before,
      request: ask,
      onAttempt: (n) => debugPrint('попытка $n… ${sw.elapsed.inSeconds} с'),
    );
    debugPrint('ПЛАН: ${run.proposal.plan.summary}');
    for (final r in run.preview.ops) {
      debugPrint(
        '  ${r.title}${r.error == null ? '' : ' — НЕ ВЫПОЛНИТЬ: ${r.error}'}',
      );
      for (final c in r.changes) {
        debugPrint('     ${c.label}: ${c.before ?? '—'} → ${c.after ?? '—'}');
      }
    }
    for (final (i, caught) in run.caught.indexed) {
      debugPrint('ПОЙМАНО перед исправлением ${i + 1}: $caught');
    }
    debugPrint('ИТОГ ПРОВЕРКИ: ${run.preview.problems.map((p) => p.message)}');
    debugPrint(
      'попыток ${run.attempts}, токены ${run.inputTokens} / ${run.outputTokens}, '
      '${sw.elapsed.inSeconds} с, применить можно: ${run.canApply}',
    );
    expect(
      run.proposal.plan.ops.length,
      greaterThan(1),
      reason: 'несколько связанных операций',
    );
    expect(run.canApply, isTrue, reason: 'после исправлений ошибок нет');

    await repo.applyChangeSet(world.id, ChangeSetDraft.fromRun(run, ask));
    final applied = await repo.snapshot(world.id);
    debugPrint('МИР ПОСЛЕ «ПРИМЕНИТЬ»:\n${show(applied)}');
    expect(show(applied), isNot(show(before)));

    // Повтор той же просьбы → «Отклонить» → мир не изменился.
    final (again, _) = await runAnswering(
      assistant: assistant,
      world: applied,
      request: ask,
    );
    debugPrint(
      'ПОВТОР: ${again.proposal.plan.summary} (${again.proposal.plan.ops.length} операций)',
    );
    await repo.rejectChangeSet(world.id, ChangeSetDraft.fromRun(again, ask));
    expect(show(await repo.snapshot(world.id)), show(applied));
    final sets = await a
        .from('change_sets')
        .select('status')
        .eq('project_id', world.id);
    expect(sets.map((s) => s['status']).toList()..sort(), [
      'applied',
      'rejected',
    ]);
  });
}
