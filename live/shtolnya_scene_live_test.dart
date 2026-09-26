// СЦЕНА «ШТОЛЬНЯ» ВЖИВУЮ (3.9) через выложенную функцию «assistant» — настоящая модель.
// В check.sh НЕ входит. Запуск:
//   bash -c 'set -a; . ./.env.test; flutter test --no-pub live/shtolnya_scene_live_test.dart'
// Автор просит утопленника с атакой 14 при потолке 10 (3 ур.): ассистент не правит молча, а
// спрашивает автора; автор берёт совет (первый вариант). Потом «Применить» → «Откатить» → мир как был.
// Ответы модели пишутся в build/live/shtolnya_*.json — по ним снимается показ (demo/).
@Tags(['live'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';

import '../test/assistant_fixtures.dart';
import '../test/db_helpers.dart';
import 'assistant_live_test.dart' show runAnswering, show;
import 'attack_question.dart';

const request =
    'Третья штольня затоплена, слизни там жить не могут. '
    'Теперь там живут утопленники 3 уровня с атакой 14.';

/// Настоящий ассистент, который запоминает каждый ответ модели.
class Recording implements AssistantService {
  Recording(this.inner);
  final AssistantService inner;
  final plans = <Map<String, dynamic>>[];

  @override
  Future<Proposal> propose(ProposeRequest r) async {
    final p = await inner.propose(r);
    plans.add(p.plan.toJson());
    return p;
  }
}

void main() {
  test('сцена «штольня» вживую: ассистент спрашивает про атаку 14, применить, откатить', () async {
    final a = await author(env('RPGB_TEST_EMAIL_A'), env('RPGB_TEST_PASSWORD'));
    final repo = SupabaseContentRepo(a);
    final world = await SupabaseWorldsRepo(a).create(
      const NewWorld(
        title: 'Пепельные копи (сцена 3.9)',
        setting: 'шахтёрский посёлок в пепельных горах',
        tone: 'мрачный',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    addTearDown(() => a.from('projects').delete().eq('id', world.id));
    await fillMines(repo, world.id);
    // RPGB_MODEL — «провайдер:модель» из providers.ts для сравнения (scripts/compare_models.sh).
    final model = Platform.environment['RPGB_MODEL'];
    final assistant = Recording(SupabaseAssistantService(a, model: model));
    final ask = ProposeRequest(
      worldId: world.id,
      scope: const Scope(ScopeType.location, 'shtolnya_3'),
      request: request,
    );

    final before = await repo.snapshot(world.id);
    debugPrint('МОДЕЛЬ: ${model ?? 'по умолчанию'}');
    debugPrint('МИР ДО:\n${show(before)}');
    final sw = Stopwatch()..start();
    final (run, asked) = await runAnswering(
      assistant: assistant,
      world: before,
      request: ask,
      onAttempt: (n) => debugPrint('попытка $n… ${sw.elapsed.inSeconds} с'),
    );
    for (final (i, caught) in run.caught.indexed) {
      debugPrint('ПОЙМАНО перед исправлением ${i + 1}: $caught');
    }
    debugPrint('ПЛАН: ${run.proposal.plan.summary}');
    for (final r in run.preview.ops) {
      debugPrint(
        '  ${r.title}${r.error == null ? '' : ' — НЕ ВЫПОЛНИТЬ: ${r.error}'}',
      );
      for (final c in r.changes) {
        debugPrint('     ${c.label}: ${c.before ?? '—'} → ${c.after ?? '—'}');
      }
    }
    debugPrint('ИТОГ ПРОВЕРКИ: ${run.preview.problems.map((p) => p.message)}');
    debugPrint(
      'изменений ${run.proposal.plan.ops.length}, попыток ${run.attempts}, '
      '${sw.elapsed.inSeconds} с, применить можно: ${run.canApply}',
    );
    Directory('build/live').createSync(recursive: true);
    for (final (i, p) in assistant.plans.indexed) {
      File('build/live/shtolnya_$i.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(p));
    }

    expect(
      asked.where(askedAboutAttack),
      isNotEmpty,
      reason: 'ассистент спросил автора про атаку выше потолка, а не исправил молча',
    );
    expect(run.canApply, isTrue, reason: 'после исправлений ошибок нет');

    await repo.applyChangeSet(world.id, ChangeSetDraft.fromRun(run, ask));
    final applied = await repo.snapshot(world.id);
    debugPrint('МИР ПОСЛЕ «ПРИМЕНИТЬ»:\n${show(applied)}');
    expect(show(applied), isNot(show(before)));
    for (final c in applied.characters.where((c) => c.role.name == 'enemy')) {
      expect(
        c.attack,
        lessThanOrEqualTo(4 + c.level * 2),
        reason: '${c.slug}: атака в потолке',
      );
    }

    final set = (await repo.history(world.id)).first;
    expect(await repo.revertConflicts(world.id, set.id), isEmpty);
    await repo.revertChangeSet(world.id, set.id);
    final reverted = await repo.snapshot(world.id);
    debugPrint('МИР ПОСЛЕ «ОТКАТИТЬ»:\n${show(reverted)}');
    expect(show(reverted), show(before), reason: 'откат вернул мир как был');
  });
}
