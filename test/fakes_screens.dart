// Подменённый ассистент и помощники экранов: запуск приложения, вход, переходы, проверки.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/app.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';
import 'package:rpg_builder/ui/object_page.dart';

import 'fakes_db.dart';

/// Подменённый ассистент: отдаёт заранее заданные планы по очереди
/// и запоминает просьбы. Кончились планы — ошибка, как у упавшей функции.
/// [answers] — по очереди: [Proposal] — план, [AuthorQuestion] — вопрос автору.
class FakeAssistant implements AssistantService {
  FakeAssistant([List<Object>? answers]) : answers = answers ?? [];
  final List<Object> answers;
  final requests = <ProposeRequest>[];

  @override
  Future<Proposal> propose(ProposeRequest request) async {
    requests.add(request);
    if (answers.isEmpty) {
      throw const AssistantException('Ассистент не ответил: нет плана');
    }
    return switch (answers.removeAt(0)) {
      final AuthorQuestion q => throw QuestionAsked(q),
      final a => a as Proposal,
    };
  }
}

/// Приложение на подменённой базе.
/// [wrap] — ключ рамки для снимков экрана (demo/snapshots_test.dart).
Future<FakeAuth> pumpApp(
  WidgetTester t, {
  FakeContent? content,
  AssistantService? assistant,
  GlobalKey? wrap,
  Open5eApi? open5e,
}) async {
  final auth = FakeAuth();
  final app = RpgBuilderApp(
    auth: auth,
    worlds: FakeWorlds(auth),
    content: content ?? FakeContent(),
    assistant: assistant ?? FakeAssistant(),
    open5e: open5e ?? const HttpOpen5e(),
  );
  await t.pumpWidget(
    wrap == null ? app : RepaintBoundary(key: wrap, child: app),
  );
  return auth;
}

/// Создаёт мир через экран «Новый мир» (уровни по умолчанию 1–10).
Future<void> createWorld(WidgetTester t, String title) async {
  await t.tap(find.byKey(const Key('new-world')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('world-title')), title);
  await t.tap(find.byKey(const Key('world-save')));
  await t.pumpAndSettle();
}

Future<void> signUp(WidgetTester t, String email) async {
  await t.enterText(find.byKey(const Key('email')), email);
  await t.enterText(find.byKey(const Key('password')), 'secret123');
  await t.tap(find.byKey(const Key('sign-up')));
  await t.pumpAndSettle();
}

/// Открывает мир из списка своих миров.
Future<void> openWorld(WidgetTester t, String title) async {
  await t.tap(find.text(title));
  await t.pumpAndSettle();
}

/// Открывает страницу объекта мира по его названию в списке.
Future<void> openObject(WidgetTester t, String title) async {
  final row = find.text(title).first;
  await t.ensureVisible(row);
  await t.pumpAndSettle();
  await t.tap(row);
  await t.pumpAndSettle();
}

/// На странице объекта есть плитка «[label]: [value]».
void expectTile(String label, String value) => expect(
  find.byWidgetPredicate(
    (w) => w is StatTile && w.label == label && w.value == value,
  ),
  findsOneWidget,
  reason: '$label: $value',
);

/// На странице персонажа в добыче есть предмет с шансом.
void expectLoot(String item, String chance) => expect(
  find.byWidgetPredicate(
    (w) =>
        w is PortraitCard &&
        w.title == item &&
        w.stats.any((s) => s.$2 == chance),
  ),
  findsOneWidget,
  reason: '$item $chance',
);
