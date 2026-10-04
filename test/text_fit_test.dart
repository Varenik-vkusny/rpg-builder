// Прибор «текст не ломается»: все экраны × ширина 360/400 dp × шрифт 1.0/1.3.
// Падает на переполнении и на переносе посреди слова. Шрифты — настоящие (real_fonts.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/character.dart';

import '../demo/question_snapshots_test.dart' show live;
import 'assistant_fixtures.dart';
import 'fakes.dart';
import 'open5e_test.dart' show FakeOpen5e, potion, warPick;
import 'real_fonts.dart';
import 'text_fit.dart';

/// Нажимает по ключу; элемент за краем списка сначала докручивается в видимую часть.
/// Список мира ленивый: строка далеко за краем ещё не построена — ищем её с начала списка.
Future<void> tapKey(WidgetTester t, Key k) async {
  if (find.byKey(k, skipOffstage: false).evaluate().isEmpty) {
    final list = find.byType(Scrollable).first;
    t.state<ScrollableState>(list).position.jumpTo(0);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.byKey(k), 200, scrollable: list);
  }
  await t.ensureVisible(find.byKey(k, skipOffstage: false));
  await t.pumpAndSettle();
  await t.tap(find.byKey(k));
  await t.pumpAndSettle();
}

Future<void> tapOn(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Системная кнопка «назад» — работает и там, где стрелки в шапке нет.
Future<void> back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
}

/// Главный путь: вход, миры, мир, страницы и формы объектов, ассистент, план, история, проверка.
Future<void> mainTour(WidgetTester t, TextFit fit) async {
  // Заголовок плана — дословно от живой модели 28.09 (снимок с телефона): длинный.
  final longTitle = Plan(
    summary:
        'Затоплена Штольня №3, слизней убрали, шаг убийства удалён, шаг сбора '
        'ключа удалён, ключ выдан как награда квеста «Обвал».',
    ops: floodPlan().ops,
  );
  final a = FakeAssistant([
    live,
    ...List.generate(3, (_) => proposal(longTitle)),
  ]);
  final content = await minesContent();
  final ambush = await addAmbush(content, minesId);
  await pumpApp(t, content: content, assistant: a, wrap: fit.frame);
  await fit.see(t, 'вход');
  await t.enterText(find.byKey(const Key('email')), 'author@test.dev');
  await t.enterText(find.byKey(const Key('password')), 'secret123');
  await tapKey(t, const Key('sign-up'));
  await fit.see(t, 'мои миры (пусто)');
  await tapKey(t, const Key('new-world'));
  await fit.see(t, 'новый мир');
  await t.enterText(find.byKey(const Key('world-title')), 'Пепельные копи');
  await tapKey(t, const Key('world-save'));
  await fit.see(t, 'мои миры');
  await tapOn(t, find.text('Пепельные копи'));
  await fit.scanScrolling(t, 'мир');

  for (final (slug, name, page) in [
    ('shtolnya_3', 'локация', 'форма локации'),
    ('klyuch', 'предмет', 'форма предмета'),
    ('slizen', 'персонаж', 'форма персонажа'),
    ('obval', 'квест', 'форма квеста'),
    (ambush.slug, 'событие', 'форма события'),
  ]) {
    await tapKey(t, Key('open-$slug'));
    await fit.scanScrolling(t, 'страница: $name');
    await tapKey(t, const Key('object-edit'));
    await fit.scanScrolling(t, page);
    await back(t);
    await back(t);
  }
  for (final kind in ['location', 'event', 'item', 'character', 'quest']) {
    await tapKey(t, Key('new-$kind'));
    await fit.scanScrolling(t, 'создать: $kind');
    await back(t);
  }

  await tapKey(t, const Key('assistant-open'));
  await fit.scanScrolling(t, 'просьба ассистенту');
  await ask(
    t,
    request: 'Третья штольня затоплена, утопленники 3 уровня с атакой 14.',
  );
  await fit.see(t, '«Ассистент уточняет»');
  await tapKey(t, const Key('question-option-1'));
  await tapKey(t, const Key('question-answer'));
  await fit.scanScrolling(t, 'план');
  await tapKey(t, const Key('plan-verdict'));
  await fit.see(t, 'шторка проверки плана');
  await t.tapAt(const Offset(20, 40));
  await t.pumpAndSettle();
  await tapKey(t, const Key('plan-review'));
  await fit.see(t, 'план по одному');
  await back(t);
  await tapKey(t, const Key('plan-apply'));
  await fit.see(t, 'мир после применения');

  await tapKey(t, const Key('history-open'));
  await fit.see(t, 'история');
  await tapOn(t, find.textContaining('Затоплена').first);
  await fit.scanScrolling(t, 'история (набор раскрыт)');
  await back(t);
  await tapKey(t, const Key('check-world'));
  await fit.scanScrolling(t, 'проверка мира');
}

/// Выход в игру: экспорт с ошибкой в мире и образец из Open5e.
Future<void> exportTour(WidgetTester t, TextFit fit) async {
  final content = await minesContent();
  await content.createCharacter(
    minesId,
    const NewCharacter(
      title: 'Призрак',
      description: '',
      role: Role.npc,
      locationId: 'loc-нет',
    ),
  );
  await pumpApp(
    t,
    content: content,
    open5e: FakeOpen5e([warPick(), potion]),
    wrap: fit.frame,
  );
  await signUp(t, 'author@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  await tapKey(t, const Key('world-export'));
  await fit.see(t, 'экспорт: ошибки в мире');
  await tapKey(t, const Key('export-cancel'));
  await tapKey(t, const Key('check-world'));
  await fit.scanScrolling(t, 'проверка мира с ошибкой');
  await back(t);
  await tapKey(t, const Key('open5e-open'));
  await fit.see(t, 'Open5e');
  await t.enterText(find.byKey(const Key('open5e-query')), 'pick');
  await tapKey(t, const Key('open5e-search'));
  await fit.scanScrolling(t, 'Open5e: найдено');
  await tapKey(t, const Key('open5e-srd-2024_war-pick'));
  await fit.scanScrolling(t, 'Open5e: план');
}

void main() {
  for (final width in [360.0, 400.0]) {
    for (final scale in [1.0, 1.3]) {
      final variant = '${width.toInt()}dp ×$scale';
      for (final (name, tour) in [
        ('главный путь', mainTour),
        ('экспорт и Open5e', exportTour),
      ]) {
        testWidgets('текст влезает: $variant, $name', (t) async {
          await t.runAsync(loadFont);
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          t.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            t.view.reset();
            t.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final fit = TextFit(variant)..start();
          try {
            await tour(t, fit);
          } finally {
            fit.stop();
          }
          expect(
            fit.problems,
            isEmpty,
            reason: '\n${fit.problems.join('\n')}\n',
          );
        });
      }
    }
  }
}
