// Экран ассистента на подменённой базе и подменённом ассистенте.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

/// Весь мир подменённой базы строкой — чтобы видеть, что в него ничего не записано.
Future<String> dump(FakeContent c) async => [
  for (final l in await c.locations(minesId)) '${l.slug}:${l.description}',
  for (final c in await c.characters(minesId))
    '${c.slug}:${c.locationId}:${c.attack}:${c.loot.length}',
  for (final q in await c.quests(minesId))
    '${q.slug}:${q.steps.map((s) => '${s.targetId}${s.amount}')}',
].join('|');

void main() {
  testWidgets('план: автор выбирает область, пишет просьбу — видит план', (
    t,
  ) async {
    final (content, assistant) = await openAssistant(t);
    final before = await dump(content);
    await ask(t);

    expect(
      find.text('Штольня №3 затоплена: слизни ушли, появились утопленники'),
      findsOneWidget,
    );
    final sent = assistant.requests.first;
    expect(sent.worldId, minesId);
    expect((sent.scope.type.name, sent.scope.slug), ('location', 'shtolnya_3'));
    expect(sent.request, 'затопи её, слизни там жить не могут');
    expect(sent.attempt, 0);
    // План — только предложение: в мире ничего не поменялось.
    expect(await dump(content), before);
  });

  testWidgets('план: область — квест или персонаж по выбору автора', (t) async {
    final (_, assistant) = await openAssistant(t);
    await ask(t, type: 'character', object: 'Слизень');
    expect(assistant.requests.first.scope.slug, 'slizen');
    expect(assistant.requests.first.scope.type.name, 'character');
  });

  testWidgets('план: без объекта области просьба не уходит', (t) async {
    final (_, assistant) = await openAssistant(t);
    await ask(t, object: null);
    expect(find.text('Выбери объект области'), findsOneWidget);
    expect(assistant.requests, isEmpty);
  });

  testWidgets('план: пустая просьба не уходит', (t) async {
    final (_, assistant) = await openAssistant(t);
    await ask(t, request: '   ');
    expect(find.text('Напиши просьбу'), findsOneWidget);
    expect(assistant.requests, isEmpty);
  });

  testWidgets('план: ошибка ассистента видна автору, мир не тронут', (t) async {
    final (content, _) = await openAssistant(t, FakeAssistant());
    final before = await dump(content);
    await ask(t);
    expect(find.text('Ассистент не ответил: нет плана'), findsOneWidget);
    expect(await dump(content), before);
  });

  test('план: запрос к функции — в формате, который она разбирает', () {
    final json = floodRequestJson();
    expect(json.keys, [
      'project_id',
      'scope',
      'request',
      'attempt',
      'previous_plan',
      'problems',
      'answers',
    ]);
    expect(json['scope'], {'type': 'location', 'slug': 'shtolnya_3'});
    // Ответы автора на вопросы ассистента — как их разбирает функция.
    final answered = const ProposeRequest(
      worldId: minesId,
      scope: Scope(ScopeType.location, 'shtolnya_3'),
      request: 'x',
      answers: [Answer('Атака 14 выше потолка 10?', 'Поставить 10')],
    ).toJson();
    expect(answered['answers'], [
      {'question': 'Атака 14 выше потолка 10?', 'answer': 'Поставить 10'},
    ]);
    // План туда и обратно — тот же, что в общем образце.
    expect(floodPlan().toJson(), floodPlanJson());
  });
}
