// Ассистент создаёт, меняет и удаляет события (5б, Ступень 2): карточки плана теми же
// виджетами, применение, откат. Модель подменена (FakeAssistant). Проверки копии мира и
// области — assistant_event_ops_copy_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/slug.dart';

import 'apply_flow_test.dart' show enabled, tapButton;
import 'assistant_event_test.dart' show del, openWithEvent;
import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'history_flow_test.dart' show openHistory;

final ambush = slugify('Засада у лебёдки');

PlanOp op(
  OpAction action,
  OpType type, {
  String? slug,
  String? event,
  String? character,
  String? item,
  Map<String, Object> fields = const {},
}) => PlanOp(
  action: action,
  type: type,
  slug: slug,
  event: event,
  character: character,
  item: item,
  fields: fields,
);

Plan plan(String summary, List<PlanOp> ops) => Plan(summary: summary, ops: ops);

const created = 'Засада в штольне: слизни и ключ';
final createPlan = plan(created, [
  op(
    OpAction.create,
    OpType.event,
    slug: 'zasada',
    fields: {
      'title': 'Засада',
      'description': 'слизни с потолка',
      'location': 'shtolnya_3',
    },
  ),
  op(
    OpAction.create,
    OpType.eventEnemy,
    event: 'zasada',
    character: 'slizen',
    fields: {'amount': 3},
  ),
  op(OpAction.create, OpType.eventItem, event: 'zasada', item: 'klyuch'),
]);

const changed = 'Засада сильнее: 5 слизней, без ключа';
final updatePlan = plan(changed, [
  op(
    OpAction.update,
    OpType.eventEnemy,
    event: ambush,
    character: 'slizen',
    fields: {'amount': 5},
  ),
  op(OpAction.delete, OpType.eventItem, event: ambush, item: 'klyuch'),
]);

const removed = 'Засады нет, слизня тоже';
final deletePlan = plan(removed, [
  op(OpAction.delete, OpType.event, slug: ambush),
  del(OpType.loot, character: 'slizen', item: 'klyuch'),
  del(OpType.questStep, item: 'klyuch'),
  del(OpType.questStep),
  del(OpType.character, slug: 'slizen'),
]);

/// Откатывает набор set-0 из истории.
Future<void> revertFirst(WidgetTester t, String summary) async {
  await openHistory(t);
  await t.tap(find.text(summary));
  await t.pumpAndSettle();
  await tapButton(t, 'revert-set-0');
  await tapButton(t, 'confirm-yes');
  expect(
    find.byKey(const Key('revert-error-set-0'), skipOffstage: false),
    findsNothing,
  );
  expect(find.textContaining('Откачен'), findsOneWidget);
}

/// Мир «Копи» с засадой на копии — для проверок без экрана.
Future<WorldSnapshot> mines({bool event = true}) async {
  final c = await minesContent();
  if (event) await addAmbush(c, minesId);
  return c.snapshot(minesId);
}

void _createTest() {
  testWidgets('создать событие: карточки, применить, откатить — события нет', (
    t,
  ) async {
    final (content, _) = await openAssistant(
      t,
      FakeAssistant([proposal(createPlan)]),
    );
    await ask(t);

    expectOp('Создать · Событие «Засада»', 'Засада');
    expectChange('Локация', null, 'Штольня №3');
    expectOp(
      'Создать · Враг в событии «Засада» → «Слизень»',
      '«Засада» → «Слизень»',
    );
    expectChange('Количество', null, '× 3');
    expectOp(
      'Создать · Предмет в событии «Засада» → «Ключ»',
      '«Засада» → «Ключ»',
    );
    expect(find.textContaining('Вне области'), findsNothing);
    expect(enabled(t, 'plan-apply'), isTrue);

    await tapButton(t, 'plan-apply');
    final e = (await content.events(minesId)).single;
    expect(e.title, 'Засада');
    expect(e.enemies.single.amount, 3);
    expect(e.items, hasLength(1));

    await revertFirst(t, created);
    expect(await content.events(minesId), isEmpty);
  });
}

void _updateTest() {
  testWidgets('изменить событие: было × 3 → стало × 5, ключ убран, откат', (
    t,
  ) async {
    final (content, _) = await openWithEvent(
      t,
      FakeAssistant([proposal(updatePlan)]),
    );
    await ask(t);

    expectChange('Количество', '× 3', '× 5');
    expectOp(
      'Удалить · Предмет в событии «Засада у лебёдки» → «Ключ»',
      '«Засада у лебёдки» → «Ключ»',
    );
    expect(enabled(t, 'plan-apply'), isTrue);

    await tapButton(t, 'plan-apply');
    final e = (await content.events(minesId)).single;
    expect(e.enemies.single.amount, 5);
    expect(e.items, isEmpty);

    await revertFirst(t, changed);
    final back = (await content.events(minesId)).single;
    expect(back.enemies.single.amount, 3);
    expect(back.items, hasLength(1));
  });
}

void _deleteTest() {
  testWidgets('удалить событие и слизня: проходит, откат возвращает оба', (
    t,
  ) async {
    final (content, _) = await openWithEvent(
      t,
      FakeAssistant(List.generate(3, (_) => proposal(deletePlan))),
    );
    await ask(t);

    // Ключ после плана нигде не достать — предупреждение, не ошибка: применять можно.
    expect(find.textContaining('стоит событие'), findsNothing);
    expect(enabled(t, 'plan-apply'), isTrue);

    await tapButton(t, 'plan-apply');
    expect(await content.events(minesId), isEmpty);
    expect(
      (await content.characters(minesId)).map((c) => c.slug),
      isNot(contains('slizen')),
    );

    await revertFirst(t, removed);
    expect((await content.events(minesId)).single.enemies.single.amount, 3);
    expect(
      (await content.characters(minesId)).map((c) => c.slug),
      contains('slizen'),
    );
  });
}

void main() {
  _createTest();
  _updateTest();
  _deleteTest();
}
