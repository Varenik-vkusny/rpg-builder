// «Попросить ассистента исправить» с экрана «Проверка мира» (3.8): проблема →
// ассистент с областью и просьбой → план → применить → проверка перечитана.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/scope.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/item.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'fakes.dart';

/// Мир копей + бешеный крот в штольне (атака 20 при потолке 8) и лебёдочный ключ,
/// который нельзя получить.
Future<FakeContent> troubled() async {
  final c = await minesContent();
  final shaft = (await c.locations(minesId)).first;
  await c.createCharacter(
    minesId,
    NewCharacter(
      title: 'Бешеный крот',
      description: '',
      role: Role.enemy,
      locationId: shaft.id,
      level: 2,
      hp: 10,
      attack: 20,
    ),
  );
  await c.createItem(
    minesId,
    const NewItem(
      title: 'Лебёдочный ключ',
      kind: ItemKind.quest,
      rarity: Rarity.common,
      level: 1,
      price: 0,
    ),
  );
  return c;
}

/// План, который усмиряет крота: атака 8 — ровно потолок.
const calmMole = Plan(
  summary: 'Крот успокоился',
  ops: [
    PlanOp(
      action: OpAction.update,
      type: OpType.character,
      slug: 'beshenyy_krot',
      fields: {'attack': 8},
    ),
  ],
);

Future<void> openCheck(WidgetTester t, FakeContent c, FakeAssistant a) async {
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpApp(t, content: c, assistant: a);
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  await t.tap(find.byKey(const Key('check-world')));
  await t.pumpAndSettle();
}

Finder fixFor(String text) => find.descendant(
  of: find.ancestor(
    of: find.textContaining(text),
    matching: find.byType(ListTile),
  ),
  matching: find.text('Исправить'),
);

void main() {
  test('исправить: область по объекту проблемы', () async {
    final w = await (await troubled()).snapshot(minesId);
    Scope? of(String title) {
      final id = [
        ...w.locations.map((x) => (x.id, x.title)),
        ...w.items.map((x) => (x.id, x.title)),
        ...w.characters.map((x) => (x.id, x.title)),
        ...w.quests.map((x) => (x.id, x.title)),
      ].firstWhere((p) => p.$2 == title).$1;
      final s = scopeForObject(w, id);
      return s;
    }

    String show(Scope? s) => s == null ? 'нет' : '${s.type.name}:${s.slug}';
    expect(show(of('Бешеный крот')), 'character:beshenyy_krot');
    expect(show(of('Обвал')), 'quest:obval');
    expect(show(of('Штольня №3')), 'location:shtolnya_3');
    // Предмет — через того, кто его роняет, или квест, где он нужен.
    expect(show(of('Ключ')), 'character:slizen');
    expect(show(of('Кирка')), 'quest:obval');
    // Ни с кем не связан — область выбирает автор.
    expect(show(of('Лебёдочный ключ')), 'нет');
  });

  testWidgets('исправить: атака крота → ассистент с областью и просьбой → '
      'применить → проблема ушла', (t) async {
    final c = await troubled();
    final a = FakeAssistant([proposal(calmMole)]);
    await openCheck(t, c, a);
    const problem = '«Бешеный крот»: атака 20 выше потолка 8 (ур. 2)';
    expect(find.text(problem), findsOneWidget);

    await t.ensureVisible(fixFor(problem));
    await t.tap(fixFor(problem));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assistant-propose')));
    await t.pumpAndSettle();
    final sent = a.requests.single;
    expect(
      (sent.scope.type, sent.scope.slug),
      (ScopeType.character, 'beshenyy_krot'),
    );
    expect(sent.request, contains(problem));

    await tapButton(t, 'plan-apply');
    // Проверка перечитывает мир после возврата — ждём её кадр.
    await t.pumpAndSettle();
    // Снова «Проверка мира» — перечитана, атаки крота в списке нет.
    expect(find.byKey(const Key('check-summary')), findsOneWidget);
    expect(find.text(problem), findsNothing);
    expect(c.changeSets.single.status, 'applied');
  });

  testWidgets('исправить: предмет нельзя получить — просьба есть, область '
      'выбирает автор', (t) async {
    final c = await troubled();
    final a = FakeAssistant([proposal(calmMole)]);
    await openCheck(t, c, a);
    await t.tap(fixFor('Лебёдочный ключ'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('assistant-propose')));
    await t.pumpAndSettle();
    expect(find.text('Выбери объект области'), findsOneWidget);
    expect(a.requests, isEmpty);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('assistant-request')))
          .controller!
          .text,
      contains('Лебёдочный ключ'),
    );
  });
}
