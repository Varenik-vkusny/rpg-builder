// Ассистент и события (5б, Ступень 2) без экрана: формат плана, ошибки копии мира с
// человеческой причиной, область. Экранные проверки — assistant_event_ops_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/assistant/plan_preview.dart';
import 'package:rpg_builder/assistant/scope.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/quest.dart';

import 'assistant_event_ops_test.dart' show ambush, createPlan, mines, op, plan;
import 'assistant_event_test.dart' show removeSlime, why;
import 'assistant_fixtures.dart';

void _formatTest() {
  test('формат плана: три вида и поле event проходят туда и обратно', () {
    final back = Plan.fromJson(createPlan.toJson());
    expect(
      [for (final o in back.ops) o.typeName],
      ['event', 'event_enemy', 'event_item'],
    );
    expect([for (final o in back.ops) o.event], [null, 'zasada', 'zasada']);
    expect(back.ops[1].integer('amount'), 3);
    expect(createPlan.toJson()['ops'][1]['event'], 'zasada');
  });
}

void _copyTests() {
  group('копия мира', () {
    Future<List<String?>> errorsOf(List<PlanOp> ops) async {
      final (_, r) = applyToCopy(await mines(), plan('x', ops));
      return [for (final x in r) x.error];
    }

    test('ошибки с человеческой причиной', () async {
      final cases = <(String, List<PlanOp>, String)>[
        (
          'событие в несуществующем месте',
          [
            op(
              OpAction.create,
              OpType.event,
              slug: 'x',
              fields: {'title': 'Х', 'location': 'nowhere'},
            ),
          ],
          'локации «nowhere» нет в мире',
        ),
        (
          'событие без места',
          [
            op(
              OpAction.create,
              OpType.event,
              slug: 'x',
              fields: {'title': 'Х'},
            ),
          ],
          'не задано: место события',
        ),
        (
          'житель вместо врага',
          [
            op(
              OpAction.create,
              OpType.eventEnemy,
              event: ambush,
              character: 'brigadir',
              fields: {'amount': 1},
            ),
          ],
          'в событии стоят только враги',
        ),
        (
          'число 0',
          [
            op(
              OpAction.update,
              OpType.eventEnemy,
              event: ambush,
              character: 'slizen',
              fields: {'amount': 0},
            ),
          ],
          'Количество — не меньше 1',
        ),
        (
          'враг дважды',
          [
            op(
              OpAction.create,
              OpType.eventEnemy,
              event: ambush,
              character: 'slizen',
              fields: {'amount': 2},
            ),
          ],
          'этот враг уже в событии',
        ),
        (
          'предмет дважды',
          [
            op(
              OpAction.create,
              OpType.eventItem,
              event: ambush,
              item: 'klyuch',
            ),
          ],
          'этот предмет уже в событии',
        ),
        (
          'предмет в несуществующее событие',
          [
            op(
              OpAction.create,
              OpType.eventItem,
              event: 'nope',
              item: 'klyuch',
            ),
          ],
          'события «nope» нет в мире',
        ),
        (
          'убрать врага, которого в событии нет',
          [
            op(
              OpAction.delete,
              OpType.eventEnemy,
              event: ambush,
              character: 'brigadir',
            ),
          ],
          'такого врага в событии нет',
        ),
        (
          'убрать предмет, которого в событии нет',
          [op(OpAction.delete, OpType.eventItem, event: ambush, item: 'kirka')],
          'такого предмета в событии нет',
        ),
        (
          'удалить событие, которого нет',
          [op(OpAction.delete, OpType.event, slug: 'nope')],
          'события «nope» нет в мире',
        ),
      ];
      final w = await mines();
      expect(w.characters.map((x) => x.slug), contains('brigadir'));
      for (final (name, ops, error) in cases) {
        final (_, r) = applyToCopy(w, plan('x', ops));
        expect(r.last.error, error, reason: name);
      }
    });

    test(
      'слизня при стоящем событии не удалить, без события — можно',
      () async {
        expect((await errorsOf(removeSlime.ops)).last, why);
        expect(
          await errorsOf([
            op(OpAction.delete, OpType.event, slug: ambush),
            ...removeSlime.ops,
          ]),
          everyElement(isNull),
        );
        // Достаточно убрать врага из события — само событие остаётся.
        expect(
          await errorsOf([
            op(
              OpAction.delete,
              OpType.eventEnemy,
              event: ambush,
              character: 'slizen',
            ),
            ...removeSlime.ops,
          ]),
          everyElement(isNull),
        );
      },
    );

    test('создание события на копии: враги и предметы лежат в нём', () async {
      final (copy, r) = applyToCopy(await mines(event: false), createPlan);
      expect(r.map((x) => x.error), everyElement(isNull));
      final e = copy.events.single;
      expect(e.slug, 'zasada');
      expect(e.enemies.single.amount, 3);
      expect(e.items, hasLength(1));
      expect(
        e.locationId,
        copy.locations.firstWhere((l) => l.slug == 'shtolnya_3').id,
      );
    });

    test('цель шага «событие» находится по slug события', () async {
      final (copy, r) = applyToCopy(
        await mines(),
        plan('шаг', [
          PlanOp(
            action: OpAction.create,
            type: OpType.questStep,
            quest: 'obval',
            position: 4,
            fields: {'step_kind': 'event', 'target': ambush},
          ),
        ]),
      );
      expect(r.single.error, isNull);
      expect(copy.quests.single.steps.last.targetId, copy.events.single.id);
    });
  });
}

void _scopeTests() {
  group('область', () {
    const scope = Scope(ScopeType.location, 'shtolnya_3');

    test(
      'событие, которого касается область, разрешено; чужое — нет',
      () async {
        final c = await minesContent();
        await addAmbush(c, minesId);
        final before = await c.snapshot(minesId);
        final far = await c.createEvent(
          minesId,
          NewEvent(
            title: 'Шум на рынке',
            description: '',
            locationId: before.locations
                .firstWhere((l) => l.slug == 'rynok')
                .id,
          ),
        );
        // Касается области любым из трёх: местом, врагом или предметом.
        String id(List<dynamic> xs, String slug) =>
            xs.firstWhere((x) => x.slug == slug).id as String;
        final place = await c.createEvent(
          minesId,
          NewEvent(
            title: 'Эхо в штольне',
            description: '',
            locationId: id(before.locations, 'shtolnya_3'),
          ),
        );
        final byEnemy = await c.createEvent(
          minesId,
          NewEvent(
            title: 'Слизень на рынке',
            description: '',
            locationId: id(before.locations, 'rynok'),
            enemies: [
              EventEnemy(
                characterId: id(before.characters, 'slizen'),
                amount: 1,
              ),
            ],
          ),
        );
        final byItem = await c.createEvent(
          minesId,
          NewEvent(
            title: 'Ключ на рынке',
            description: '',
            locationId: id(before.locations, 'rynok'),
            itemIds: [id(before.items, 'klyuch')],
          ),
        );
        final world = await c.snapshot(minesId);
        expect(eventKeysInScope(world, scopeOf(world, scope)), {
          'event:$ambush',
          'event:${place.slug}',
          'event:${byEnemy.slug}',
          'event:${byItem.slug}',
        });

        final out = previewPlan(
          world,
          plan('x', [
            op(
              OpAction.update,
              OpType.eventEnemy,
              event: ambush,
              character: 'slizen',
              fields: {'amount': 4},
            ),
            op(OpAction.delete, OpType.event, slug: far.slug),
            op(
              OpAction.create,
              OpType.eventItem,
              event: far.slug,
              item: 'klyuch',
            ),
          ]),
          scope,
        ).outside;
        expect(out.keys, [1, 2]);
        expect(out[1], ['event:${far.slug}']);
        expect(out[2], ['event:${far.slug}']);
      },
    );

    test(
      'созданное планом событие разрешено, в чужом месте — вне области',
      () async {
        final world = await mines(event: false);
        expect(previewPlan(world, createPlan, scope).outside, isEmpty);
        final bad = plan('x', [
          op(
            OpAction.create,
            OpType.event,
            slug: 'zasada',
            fields: {'title': 'Засада', 'location': 'rynok'},
          ),
        ]);
        expect(previewPlan(world, bad, scope).outside[0], ['location:rynok']);
      },
    );

    test('шаг квеста области, ведущий к событию, открывает событие', () async {
      final w = await mines();
      final event = w.events.single;
      final q = w.quests.single;
      final world = WorldSnapshot(
        locations: w.locations,
        items: w.items,
        characters: w.characters,
        quests: [
          Quest(
            id: q.id,
            slug: q.slug,
            title: q.title,
            description: q.description,
            giverId: q.giverId,
            steps: [QuestStep(kind: StepKind.event, targetId: event.id)],
            rewardIds: q.rewardIds,
          ),
        ],
        events: [
          Event(
            id: event.id,
            slug: event.slug,
            title: event.title,
            description: event.description,
            locationId: w.locations.firstWhere((l) => l.slug == 'rynok').id,
          ),
        ],
      );
      expect(eventKeysInScope(world, {'quest:${q.slug}'}), {
        'event:${event.slug}',
      });
      expect(eventKeysInScope(world, {'item:klyuch'}), isEmpty);
    });
  });
}

/// Квест «Обвал» получает четвёртый шаг «пройти засаду» — как после ручной правки.
PlanOp _stepToAmbush() => PlanOp(
  action: OpAction.create,
  type: OpType.questStep,
  quest: 'obval',
  position: 4,
  fields: {'step_kind': 'event', 'target': ambush},
);

void _stepGuardTests() {
  test('событие под шагом квеста не удалить; убрав шаг — можно', () async {
    final w = await mines();
    final drop = op(OpAction.delete, OpType.event, slug: ambush);
    final (_, blocked) = applyToCopy(w, plan('x', [_stepToAmbush(), drop]));
    expect(blocked.last.error, contains('на него ещё ссылаются'));
    expect(blocked.last.error, contains('шаг 4 квеста'));

    final unstep = PlanOp(
      action: OpAction.delete,
      type: OpType.questStep,
      quest: 'obval',
      position: 4,
    );
    final (copy, ok) = applyToCopy(
      w,
      plan('x', [_stepToAmbush(), unstep, drop]),
    );
    expect(ok.map((r) => r.error), everyElement(isNull));
    expect(copy.events, isEmpty);
    expect(copy.quests.single.steps, hasLength(3));
  });
}

void main() {
  _formatTest();
  _copyTests();
  _stepGuardTests();
  _scopeTests();
}
