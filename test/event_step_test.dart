// Шаг квеста «пройти событие» (5б.3): цель шага — событие; шаг на несуществующее событие —
// ошибка проверки; событие под шагом квеста не удаляется; в форме квеста цель выбирается
// из событий мира, на странице квеста шаг ведёт на страницу события.
// Как шаг ложится в базу — test/event_db_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/assistant/scope.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/content/quest.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'event_flow_test.dart' show choose;
import 'fakes.dart';

/// «Пепельные копи» с «Засадой у лебёдки» и квестом «Обвал», у которого четвёртый шаг —
/// пройти эту засаду. Возвращает базу и id события.
Future<(FakeContent, String)> minesWithEventStep() async {
  final c = await minesContent();
  final ambush = await addAmbush(c, minesId);
  final q = (await c.quests(minesId)).single;
  await c.applyManualEdit(
    minesId,
    editQuest(
      minesId,
      q,
      NewQuest(
        title: q.title,
        description: q.description,
        giverId: q.giverId!,
        steps: [
          ...q.steps,
          QuestStep(kind: StepKind.event, targetId: ambush.id),
        ],
        rewardIds: q.rewardIds,
      ),
    ),
  );
  return (c, ambush.id);
}

Future<void> openWorldWith(WidgetTester t, FakeContent content) async {
  t.view.physicalSize = const Size(800, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpApp(t, content: content, assistant: FakeAssistant());
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
}

void main() {
  group('шаг «пройти событие»: модель и правила', () {
    test('строка базы ↔ шаг: цель — событие, количества нет', () {
      const step = QuestStep(kind: StepKind.event, targetId: 'event-1');
      expect(step.toJson(), {'kind': 'event', 'event_id': 'event-1'});
      final back = QuestStep.fromRow({
        'kind': 'event',
        'character_id': null,
        'item_id': null,
        'location_id': null,
        'event_id': 'event-1',
        'amount': null,
      });
      expect((back.kind, back.targetId, back.amount), (
        StepKind.event,
        'event-1',
        null,
      ));
      expect(step.label('Засада у лебёдки'), 'Пройти событие: Засада у лебёдки');
    });

    test('шаг на существующее событие — проблем нет; события нет — ошибка', () async {
      final (c, _) = await minesWithEventStep();
      final w = await c.snapshotOf(minesId);
      final before = checkWorld(await (await minesContent()).snapshotOf(minesId));
      expect(
        [for (final p in checkWorld(w)) p.message],
        [for (final p in before) p.message],
      );

      final gone = WorldSnapshot(
        locations: w.locations,
        items: w.items,
        characters: w.characters,
        quests: w.quests,
      );
      expect(
        [
          for (final p in checkWorld(gone))
            if (p.severity == Severity.error) p.message,
        ],
        ['«Обвал»: шаг 4 ссылается на несуществующий объект'],
      );
    });

    test('событие под шагом квеста удалить нельзя', () async {
      final (c, eventId) = await minesWithEventStep();
      final w = await c.snapshotOf(minesId);
      expect(referencesTo(w, eventId), ['шаг 4 квеста «Обвал»']);
    });

    test('правка квеста пишет шагу столбец события', () async {
      final (c, eventId) = await minesWithEventStep();
      final rows = [
        for (final op in c.journal.last.entry.ops) '${op.action} ${op.type}',
      ];
      expect(rows.where((r) => r == 'create quest_step'), hasLength(4));
      final q = (await c.quests(minesId)).single;
      final edit = editQuest(
        minesId,
        q,
        NewQuest(
          title: q.title,
          description: q.description,
          giverId: q.giverId!,
          steps: q.steps.reversed.toList(),
          rewardIds: q.rewardIds,
        ),
      );
      final created = [
        for (final op in edit.ops)
          if (op['action'] == 'create') op['row'] as Map,
      ];
      expect(created.first['kind'], 'event');
      expect(created.first['event_id'], eventId);
      expect(created.first['character_id'], isNull);
      expect(created.last['event_id'], isNull);
    });

    test('ассистент на мире с таким шагом: область считается, образцовый план '
        'проходит копию', () async {
      final (c, _) = await minesWithEventStep();
      final w = await c.snapshotOf(minesId);
      expect(
        scopeOf(w, const Scope(ScopeType.location, 'shtolnya_3')),
        contains('quest:obval'),
      );
      final (copy, results) = applyToCopy(w, floodPlan());
      expect([for (final r in results) r.error], everyElement(isNull));
      expect(copy.quests.single.steps.last.kind, StepKind.event);
    });
  });

  testWidgets('форма квеста: шаг «Пройти событие» — цель из событий мира; на '
      'странице квеста шаг ведёт на событие', (t) async {
    final content = await minesContent();
    await addAmbush(content, minesId);
    await openWorldWith(t, content);

    await tapButton(t, 'open-obval');
    await tapButton(t, 'object-edit');
    await tapButton(t, 'step-add');
    final i = (await content.quests(minesId)).single.steps.length;
    await choose(t, 'step-kind-$i', 'Пройти событие');
    // В списке целей — только события: ни персонажей, ни мест.
    final slimes = find.text('Слизень').evaluate().length;
    await tapButton(t, 'step-target-$i-event');
    expect(find.text('Засада у лебёдки'), findsWidgets);
    expect(find.text('Слизень').evaluate().length, slimes);
    expect(find.text('Штольня №3'), findsNothing);
    await t.tap(find.text('Засада у лебёдки').last);
    await t.pumpAndSettle();
    // Количества у такого шага нет.
    expect(find.byKey(Key('step-amount-$i')), findsNothing);
    await tapButton(t, 'quest-save');

    final step = (await content.quests(minesId)).single.steps.last;
    expect(step.kind, StepKind.event);
    expect(step.targetId, (await content.events(minesId)).single.id);

    await tapButton(t, 'open-obval');
    final cell = find.text('${i + 1}. Пройти событие: Засада у лебёдки');
    expect(cell, findsOneWidget);
    await t.ensureVisible(cell);
    await t.tap(cell);
    await t.pumpAndSettle();
    expect(find.text('Событие'), findsOneWidget);
    expect(find.byKey(const Key('enemy-slizen')), findsOneWidget);
  });

  testWidgets('событие под шагом квеста: «Удалить» отказывает и называет квест', (
    t,
  ) async {
    final (content, eventId) = await minesWithEventStep();
    await openWorldWith(t, content);
    final slug = (await content.events(minesId)).single.slug;
    await tapButton(t, 'open-$slug');
    await tapButton(t, 'object-edit');
    await tapButton(t, 'object-delete');
    expect(find.textContaining('шаг 4 квеста «Обвал»'), findsOneWidget);
    expect((await content.events(minesId)).single.id, eventId);
  });
}
