// Ассистент и события (5б, Ступень 1): план, убирающий врага, предмет или место
// из-под события, — ошибка на копии с причиной «на … стоит событие …».
// Экран на подменённой модели (FakeAssistant) и копия мира без экрана.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/assistant/scope.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';

import 'apply_flow_test.dart' show enabled;
import 'assistant_fixtures.dart';
import 'assistant_flow_test.dart' show dump;
import 'fakes.dart';

PlanOp del(OpType type, {String? slug, String? character, String? item}) =>
    PlanOp(
      action: OpAction.delete,
      type: type,
      slug: slug,
      character: character,
      item: item,
      quest: type == OpType.questStep ? 'obval' : null,
      position: type == OpType.questStep ? (item == null ? 2 : 3) : null,
    );

/// Как openAssistant, но мир «Копи» уже с событием: экран мира читает его при открытии.
Future<(FakeContent, FakeAssistant)> openWithEvent(
  WidgetTester t, [
  FakeAssistant? assistant,
]) async {
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final content = await minesContent();
  await addAmbush(content, minesId);
  final a =
      assistant ??
      FakeAssistant(List.generate(3, (_) => proposal(floodPlan())));
  await pumpApp(t, content: content, assistant: a);
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  await t.tap(find.byKey(const Key('assistant-open')));
  await t.pumpAndSettle();
  return (content, a);
}

/// Слизня убирают честно: сначала добыча и шаг «убить», потом он сам.
/// Единственная помеха удалению — событие.
final removeSlime = Plan(
  summary: 'убрать слизня',
  ops: [
    del(OpType.loot, character: 'slizen', item: 'klyuch'),
    const PlanOp(
      action: OpAction.delete,
      type: OpType.questStep,
      quest: 'obval',
      position: 2,
    ),
    del(OpType.character, slug: 'slizen'),
  ],
);

const why = 'на «Слизень» стоит событие «Засада у лебёдки»';

List<String?> errors(List<OpResult> r) => [for (final x in r) x.error];

void main() {
  testWidgets(
    'событие: убрать слизня из-под события — ошибка на копии, мир цел',
    (t) async {
      final a = FakeAssistant(List.generate(4, (_) => proposal(removeSlime)));
      final (content, _) = await openWithEvent(t, a);
      final before = await dump(content);
      await ask(t, request: 'убери слизня');

      await openVerdict(t);
      expect(find.textContaining(why), findsWidgets);
      // Эту же строку получает модель как проблему на исправление.
      expect(a.requests.last.problems.join('|'), contains(why));
      expect(enabled(t, 'plan-apply'), isFalse);
      expect(await dump(content), before);
      expect((await content.events(minesId)).single.enemies.single.amount, 3);
      expect(content.changeSets, isEmpty);
    },
  );

  testWidgets(
    'событие: образцовый план потопа проходит копию без ошибок от события',
    (t) async {
      final (content, _) = await openWithEvent(t);
      await ask(t);

      expect(find.textContaining('стоит событие'), findsNothing);
      final (copy, results) = applyToCopy(
        await content.snapshot(minesId),
        floodPlan(),
      );
      expect(errors(results), everyElement(isNull));
      // Событие переживает план: копия помнит его, слизень стоит на месте.
      expect(copy.events.single.title, 'Засада у лебёдки');
      expect(copy.characters.map((c) => c.slug), contains('slizen'));
    },
  );

  test(
    'событие: враг, предмет и место под событием не удаляются на копии',
    () async {
      final c = await minesContent();
      await addAmbush(c, minesId);
      final w = await c.snapshot(minesId);
      const quest = 'Засада у лебёдки';

      final (_, enemy) = applyToCopy(w, removeSlime);
      expect(enemy.last.error, 'на «Слизень» стоит событие «$quest»');
      expect(enemy.take(2).map((r) => r.error), everyElement(isNull));

      final (_, item) = applyToCopy(
        w,
        Plan(
          summary: 'убрать ключ',
          ops: [
            del(OpType.loot, character: 'slizen', item: 'klyuch'),
            del(OpType.questStep, item: 'klyuch'),
            del(OpType.item, slug: 'klyuch'),
          ],
        ),
      );
      expect(item.last.error, 'на «Ключ» стоит событие «$quest»');
      expect(item.take(2).map((r) => r.error), everyElement(isNull));

      final (_, place) = applyToCopy(
        w,
        Plan(
          summary: 'убрать штольню',
          ops: [
            const PlanOp(
              action: OpAction.update,
              type: OpType.character,
              slug: 'slizen',
              fields: {'location': 'rynok'},
            ),
            del(OpType.location, slug: 'shtolnya_3'),
          ],
        ),
      );
      expect(place.first.error, isNull);
      expect(place.last.error, 'на «Штольня №3» стоит событие «$quest»');

      // Без события те же удаления проходят: ошибку даёт именно оно.
      final (_, free) = applyToCopy(
        WorldSnapshot(
          locations: w.locations,
          items: w.items,
          characters: w.characters,
          quests: w.quests,
        ),
        removeSlime,
      );
      expect(errors(free), everyElement(isNull));
    },
  );

  test(
    'событие: цель шага «пройти событие» — событие, состав области прежний',
    () async {
      expect(stepTargetType('event'), 'event');
      final c = await minesContent();
      const scope = Scope(ScopeType.location, 'shtolnya_3');
      final clean = scopeOf(await c.snapshot(minesId), scope);
      await addAmbush(c, minesId);
      final withEvent = scopeOf(await c.snapshot(minesId), scope);
      expect(withEvent, clean);
      expect(withEvent.where((k) => k.startsWith('event:')), isEmpty);
    },
  );
}
