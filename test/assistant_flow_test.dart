// Экран ассистента на подменённой базе и подменённом ассистенте.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

/// Мир «Пепельные копи» открыт, экран ассистента открыт.
Future<(FakeContent, FakeAssistant)> openAssistant(
  WidgetTester t, [
  FakeAssistant? assistant,
]) async {
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final content = await minesContent();
  final a = assistant ?? FakeAssistant([proposal(floodPlan())]);
  await pumpApp(t, content: content, assistant: a);
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  await t.tap(find.byKey(const Key('assistant-open')));
  await t.pumpAndSettle();
  return (content, a);
}

/// Выбирает область и пишет просьбу.
Future<void> ask(
  WidgetTester t, {
  String type = 'location',
  String? object = 'Штольня №3',
  String request = 'затопи её, слизни там жить не могут',
}) async {
  await t.tap(find.byKey(Key('scope-type-$type')));
  await t.pumpAndSettle();
  if (object != null) {
    await t.tap(find.byKey(Key('scope-object-$type')));
    await t.pumpAndSettle();
    await t.tap(find.text(object).last);
    await t.pumpAndSettle();
  }
  await t.enterText(find.byKey(const Key('assistant-request')), request);
  await t.tap(find.byKey(const Key('assistant-propose')));
  await t.pumpAndSettle();
}

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
    final sent = assistant.requests.single;
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
    expect(assistant.requests.single.scope.slug, 'slizen');
    expect(assistant.requests.single.scope.type.name, 'character');
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
    ]);
    expect(json['scope'], {'type': 'location', 'slug': 'shtolnya_3'});
    // План туда и обратно — тот же, что в общем образце.
    expect(floodPlan().toJson(), floodPlanJson());
  });
}
