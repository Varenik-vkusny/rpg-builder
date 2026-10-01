// ПРИЁМКА 5а.6 ВЖИВУЮ: «Затопи копи» меняет штольни внутри. Настоящая модель через
// выложенную функцию «assistant». В check.sh НЕ входит. Запуск:
//   bash -c 'set -a; . ./.env.test; flutter test --no-pub live/kopi_flood_live_test.dart'
// Мир: Копи › Штольня №3 (со слизнем) и Рынок рядом. Область — Копи.
// Прибор: судья live/kopi_flood_judge.dart (описание Штольни №3 изменено; житель удалён — только
// после вопроса автору), Рынок не тронут, план применяется и откатывается.
@Tags(['live'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';

import '../test/assistant_fixtures.dart';
import '../test/db_helpers.dart';
import 'assistant_live_test.dart' show runAnswering, show;
import 'kopi_flood_judge.dart';

void main() {
  test('«затопи копи» вживую: меняются штольни внутри копей', () async {
    final a = await testAuthor();
    final repo = SupabaseContentRepo(a);
    final world = await SupabaseWorldsRepo(a).create(
      const NewWorld(
        title: 'Пепельные копи (5а.6)',
        setting: 'шахтёрский посёлок в пепельных горах',
        tone: 'мрачный',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    addTearDown(() => a.from('projects').delete().eq('id', world.id));
    await fillMines(repo, world.id);
    final kopi = await repo.createLocation(
      world.id,
      const NewLocation(
        title: 'Копи',
        description: 'старые выработки под посёлком',
        levelMin: 1,
        levelMax: 6,
      ),
    );
    await a
        .from('locations')
        .update({'parent_id': kopi.id})
        .eq('project_id', world.id)
        .eq('slug', 'shtolnya_3');

    final model = Platform.environment['RPGB_MODEL'];
    final ask = ProposeRequest(
      worldId: world.id,
      scope: Scope(ScopeType.location, kopi.slug),
      request: 'Затопи копи: вода поднялась по пояс, слизни там жить не могут.',
    );
    final before = await repo.snapshot(world.id);
    debugPrint('МИР ДО:\n${show(before)}');
    final (run, asked) = await runAnswering(
      assistant: SupabaseAssistantService(a, model: model),
      world: before,
      request: ask,
    );
    debugPrint('ПЛАН: ${run.proposal.plan.summary}');
    for (final r in run.preview.ops) {
      debugPrint('  ${r.title}${r.error == null ? '' : ' — ${r.error}'}');
    }

    final touched = {
      for (final op in run.proposal.plan.ops) ...[?op.slug, ?op.character],
      for (final op in run.proposal.plan.ops) ?op.str('location'),
    };
    expect(
      judgeKopiFlood(run.proposal.plan, questionsAsked: asked.length),
      isEmpty,
      reason: 'план: $touched',
    );
    expect(touched, isNot(contains('rynok')), reason: 'Рынок вне копей');
    expect(run.canApply, isTrue, reason: 'после исправлений ошибок нет');

    await repo.applyChangeSet(world.id, ChangeSetDraft.fromRun(run, ask));
    final set = (await repo.history(world.id)).first;
    await repo.revertChangeSet(world.id, set.id);
    expect(show(await repo.snapshot(world.id)), show(before));
  });
}
