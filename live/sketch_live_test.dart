// СКЕТЧ ВЖИВУЮ (4.4) через выложенную функцию «assistant» — настоящая модель со зрением (qwen на Groq).
// В check.sh НЕ входит: тратит суточный лимит модели. Запуск:
//   bash -c 'set -a; . ./.env.test; flutter test --no-pub live/sketch_live_test.dart'
// Автор Т фотографирует рисунок лампщицы (test/fixtures/sketch_merchant.png) в области «Штольня №3»:
// план создаёт персонажа по рисунку, проверка на копии без ошибок, «Применить» — персонаж в мире.
@Tags(['live'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';

import '../test/assistant_fixtures.dart';
import '../test/db_helpers.dart';
import 'assistant_live_test.dart' show runAnswering, show;

void main() {
  test('скетч вживую: рисунок лампщицы → план «создать персонажа» → применить', () async {
    final a = await testAuthor();
    final repo = SupabaseContentRepo(a);
    final world = await SupabaseWorldsRepo(a).create(
      const NewWorld(
        title: 'Пепельные копи (скетч 4.4)',
        setting: 'шахтёрский посёлок в пепельных горах',
        tone: 'мрачный',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    addTearDown(() => a.from('projects').delete().eq('id', world.id));
    await fillMines(repo, world.id);
    final before = await repo.snapshot(world.id);

    final ask = ProposeRequest(
      worldId: world.id,
      scope: const Scope(ScopeType.location, 'shtolnya_3'),
      request: 'Создай персонажа по этому скетчу',
      image: SketchImage(
        File('test/fixtures/sketch_merchant.png').readAsBytesSync(),
        'image/png',
      ),
    );
    final sw = Stopwatch()..start();
    final (run, asked) = await runAnswering(
      assistant: SupabaseAssistantService(a),
      world: before,
      request: ask,
      onAttempt: (n) => debugPrint('попытка $n… ${sw.elapsed.inSeconds} с'),
    );
    debugPrint('ВОПРОСОВ: ${asked.length}');
    debugPrint('ПЛАН: ${run.proposal.plan.summary}');
    for (final r in run.preview.ops) {
      debugPrint('  ${r.title}${r.error == null ? '' : ' — НЕ ВЫПОЛНИТЬ: ${r.error}'}');
      for (final c in r.changes) {
        debugPrint('     ${c.label}: ${c.before ?? '—'} → ${c.after ?? '—'}');
      }
    }
    debugPrint('токенов ${run.inputTokens}+${run.outputTokens}, ${sw.elapsed.inSeconds} с');
    Directory('build/live').createSync(recursive: true);
    File('build/live/sketch.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(run.proposal.plan.toJson()),
    );

    final created = run.proposal.plan.ops.where(
      (o) => o.action == OpAction.create && o.type == OpType.character,
    );
    expect(created, isNotEmpty, reason: 'по скетчу создан персонаж');
    expect(run.canApply, isTrue, reason: 'проверка на копии без ошибок');

    await repo.applyChangeSet(world.id, ChangeSetDraft.fromRun(run, ask));
    final applied = await repo.snapshot(world.id);
    debugPrint('МИР ПОСЛЕ «ПРИМЕНИТЬ»:\n${show(applied)}');
    final slugs = {for (final c in applied.characters) c.slug};
    for (final o in created) {
      expect(slugs, contains(o.slug), reason: 'персонаж ${o.slug} в мире');
    }
  });
}
