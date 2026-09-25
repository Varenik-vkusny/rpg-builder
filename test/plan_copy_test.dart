// План на копии мира (3.3): «было → стало» по полям, созданное и удалённое,
// проверка мира на копии. Настоящий мир не меняется.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_apply.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

Future<WorldSnapshot> mines() async => (await minesContent()).snapshot(minesId);

/// Изменения операции строками «Поле: было → стало».
List<String> lines(OpResult r) => [
  for (final c in r.changes)
    '${c.label}: ${c.before ?? '—'} → ${c.after ?? '—'}',
];

Plan one(PlanOp op) => Plan(summary: '', ops: [op]);

void main() {
  copyDeleteRefs();
  test('копия: план затопления — было → стало по каждой операции', () async {
    final world = await mines();
    final (copy, results) = applyToCopy(world, floodPlan());

    expect(results.map((r) => r.error), everyElement(isNull));
    expect(results.map((r) => r.title), [
      'Изменить · Локация «Штольня №3»',
      'Создать · Персонаж «Утопленник»',
      'Удалить · Добыча «Слизень» → «Ключ»',
      'Создать · Добыча «Утопленник» → «Ключ»',
      'Изменить · Шаг квеста «Обвал», шаг 2',
    ]);
    expect(lines(results[0]), [
      'Описание: обвалившаяся выработка → затоплена по пояс',
    ]);
    expect(lines(results[1]), [
      'Название: — → Утопленник',
      'Роль: — → Враг',
      'Уровень: — → 3',
      'Здоровье: — → 30',
      'Атака: — → 14',
      'Локация: — → Штольня №3',
    ]);
    expect(lines(results[2]), ['Шанс: 35% → —']);
    expect(lines(results[3]), ['Шанс: — → 35%']);
    expect(lines(results[4]), [
      'Шаг 2: Убить: Слизень × 4 → Убить: Утопленник × 3',
    ]);

    // Копия изменилась, настоящий мир — нет.
    expect(copy.characters.map((c) => c.title), contains('Утопленник'));
    expect(world.characters.map((c) => c.title), isNot(contains('Утопленник')));
    expect(world.locations.first.description, 'обвалившаяся выработка');
  });

  test('копия: проверка мира на копии ловит атаку 14 при потолке 10', () async {
    final (copy, _) = applyToCopy(await mines(), floodPlan());
    expect([
      for (final p in checkWorld(copy)) p.message,
    ], contains('«Утопленник»: атака 14 выше потолка 10 (ур. 3)'));
  });

  // Ловит сама операция, до проверки мира: база не даст удалить объект со ссылками.
  test(
    'копия: удалённый объект со ссылками — операция не выполняется',
    () async {
      final (_, results) = applyToCopy(
        await mines(),
        one(
          const PlanOp(
            action: OpAction.delete,
            type: OpType.character,
            slug: 'slizen',
          ),
        ),
      );
      expect(results.single.title, 'Удалить · Персонаж «Слизень»');
      expect(results.single.error, contains('шаг 2 квеста «Обвал»'));
    },
  );

  for (final (name, op, error) in [
    (
      'объекта нет в мире',
      const PlanOp(
        action: OpAction.update,
        type: OpType.location,
        slug: 'net',
        fields: {'title': 'x'},
      ),
      'локации «net» нет в мире',
    ),
    (
      'занятый slug',
      const PlanOp(
        action: OpAction.create,
        type: OpType.item,
        slug: 'kirka',
        fields: {'title': 'x'},
      ),
      'slug «kirka» уже занят',
    ),
    (
      'смена роли',
      const PlanOp(
        action: OpAction.update,
        type: OpType.character,
        slug: 'slizen',
        fields: {'role': 'npc'},
      ),
      'роль персонажа не меняется',
    ),
    (
      'добыча у жителя',
      const PlanOp(
        action: OpAction.create,
        type: OpType.loot,
        character: 'brigadir',
        item: 'kirka',
        fields: {'chance': 10},
      ),
      'добыча бывает только у врага',
    ),
    (
      'шанс 150',
      const PlanOp(
        action: OpAction.update,
        type: OpType.loot,
        character: 'slizen',
        item: 'klyuch',
        fields: {'chance': 150},
      ),
      'шанс — больше 0 и не больше 100',
    ),
    (
      'шаг не в конец',
      const PlanOp(
        action: OpAction.create,
        type: OpType.questStep,
        quest: 'obval',
        position: 1,
        fields: {'step_kind': 'talk', 'target': 'brigadir'},
      ),
      'новый шаг — только в конец, номер 4',
    ),
    (
      'убить жителя',
      const PlanOp(
        action: OpAction.update,
        type: OpType.questStep,
        quest: 'obval',
        position: 2,
        fields: {'target': 'brigadir'},
      ),
      'убить можно только врага',
    ),
    (
      'урон у квестового предмета',
      const PlanOp(
        action: OpAction.update,
        type: OpType.item,
        slug: 'klyuch',
        fields: {'damage': 3},
      ),
      'урон бывает только у оружия',
    ),
  ]) {
    test('копия: $name — операция не выполняется, причина видна', () async {
      final world = await mines();
      final (copy, results) = applyToCopy(world, one(op));
      expect(results.single.error, error);
      expect(results.single.changes, isEmpty);
    });
  }

  test('копия: удаление шага сдвигает следующие', () async {
    final (copy, results) = applyToCopy(
      await mines(),
      one(
        const PlanOp(
          action: OpAction.delete,
          type: OpType.questStep,
          quest: 'obval',
          position: 1,
        ),
      ),
    );
    expect(lines(results.single), ['Шаг 1: Поговорить: Бригадир → —']);
    expect(copy.quests.single.steps.map((s) => s.kind.name), [
      'kill',
      'collect',
    ]);
  });

  testWidgets('копия: экран плана — было → стало и итог проверки до записи', (
    t,
  ) async {
    final (content, _) = await openAssistant(t);
    await ask(t);

    expect(find.text('Изменить · Локация «Штольня №3»'), findsOneWidget);
    expect(
      find.text('Описание: обвалившаяся выработка → затоплена по пояс'),
      findsOneWidget,
    );
    expect(find.text('Создать · Персонаж «Утопленник»'), findsOneWidget);
    expect(find.text('Атака: 14'), findsOneWidget);
    expect(find.text('Шанс: 35% → удалено'), findsOneWidget);
    expect(
      find.text('Шаг 2: Убить: Слизень × 4 → Убить: Утопленник × 3'),
      findsOneWidget,
    );
    expect(
      find.text('Проверка на копии мира — ошибок: 0 · предупреждений: 1'),
      findsOneWidget,
    );
    expect(
      find.text('«Утопленник»: атака 14 выше потолка 10 (ур. 3)'),
      findsOneWidget,
    );
    // Всё это — на копии: в базе утопленника нет.
    final chars = await content.characters(minesId);
    expect(chars.map((c) => c.title), isNot(contains('Утопленник')));
  });

  testWidgets('копия: невыполнимая операция — ошибка с причиной', (t) async {
    final bad = Plan(
      summary: 'Добыча жителю',
      ops: const [
        PlanOp(
          action: OpAction.create,
          type: OpType.loot,
          character: 'slizen',
          item: 'klyuch',
          fields: {'chance': 10},
        ),
      ],
    );
    await openAssistant(
      t,
      FakeAssistant(List.generate(3, (_) => proposal(bad))),
    );
    await ask(t);
    expect(
      find.text('Проверка на копии мира — ошибок: 1 · предупреждений: 0'),
      findsOneWidget,
    );
    expect(
      find.text('Не выполнить: этот предмет уже в добыче'),
      findsOneWidget,
    );
  });
}

/// Операция «удалить слизня» по образцу из плана затопления.
PlanOp deleteSlime() {
  final j = Map<String, dynamic>.of(
    (floodPlanJson()['ops'] as List)[1] as Map<String, dynamic>,
  );
  j['action'] = 'delete';
  j['slug'] = 'slizen';
  j['fields'] = {for (final k in (j['fields'] as Map).keys) k: null};
  return PlanOp.fromJson(j);
}

void copyDeleteRefs() {
  test('копия: удалить врага, пока на него ссылается шаг квеста, — ошибка, как в базе', () async {
    final flood = floodPlan().ops;
    // Живой прогон 25.09: слизень удалён раньше, чем шаг квеста переписан на утопленника.
    final early = Plan(summary: '', ops: [flood[1], deleteSlime(), flood[4]]);
    final (_, bad) = applyToCopy(await mines(), early);
    expect(bad[1].error, contains('шаг 2 квеста «Обвал»'));

    // Сначала ссылки убраны — удаление проходит; своя добыча уходит вместе со слизнем.
    final late = Plan(summary: '', ops: [flood[1], flood[4], deleteSlime()]);
    final (copy, ok) = applyToCopy(await mines(), late);
    expect(ok.map((r) => r.error), everyElement(isNull));
    expect(copy.characters.map((c) => c.slug), isNot(contains('slizen')));
  });
}
