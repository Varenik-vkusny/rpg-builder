// Вид А, срез 5: страницы объектов и строка события — имя один раз, свойства плашками
// без склеек «·», подписи счётчиков мира одного кегля.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_map_test.dart' show minesWithEvents;
import 'object_links_test.dart' show open, openMines;
import 'place_page_test.dart' show openWorldOf;
import 'real_fonts.dart';

/// Страница показывает имя один раз: в шапке его нет, склеек « · » нет.
void expectNameOnceNoGlue(String name) {
  expect(find.text(name), findsOneWidget, reason: 'имя «$name» не один раз');
  expect(
    find.descendant(of: find.byType(AppBar), matching: find.text(name)),
    findsNothing,
    reason: 'имя «$name» в шапке',
  );
  expect(find.textContaining(' · '), findsNothing, reason: 'склейка «·»');
}

void main() {
  testWidgets('страница предмета: имя один раз, вид и редкость плашками', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'klyuch');
    expectNameOnceNoGlue('Ключ');
    expect(find.text('Квестовый'), findsOneWidget);
    expect(find.text('Обычный'), findsOneWidget);
    // «Роняет: Слизень · 35%» — имя строкой, шанс отдельной плашкой.
    expect(find.text('35%'), findsOneWidget);
  });

  testWidgets('страница врага: имя один раз, место плашкой, роль плашкой', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'slizen');
    expectNameOnceNoGlue('Слизень');
    expect(find.text('Штольня №3'), findsOneWidget);
    expect(find.text('Враг'), findsOneWidget);
  });

  testWidgets('страница квеста: имя один раз, без пояснения «Кто выдаёт…»', (
    t,
  ) async {
    await openMines(t);
    await open(t, 'obval');
    expectNameOnceNoGlue('Обвал');
    expect(find.textContaining('Кто выдаёт'), findsNothing);
    expect(find.text('Квест'), findsNothing);
  });

  testWidgets('строка события в мире: место и враги — плашками', (t) async {
    t.view.physicalSize = const Size(800, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await openWorldOf(t, await minesWithEvents());
    expect(find.text('Слизень ×3'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
    expect(find.textContaining('×3 ·'), findsNothing);
  });

  testWidgets('счётчики мира: у всех пяти подписей один кегль на ширине 360', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Тестовый шрифт делает каждую букву квадратом — меряем настоящим.
    await t.runAsync(loadFont);
    await openWorldOf(t, await minesWithEvents());
    final sizes = {
      for (final k in ['locations', 'items', 'characters', 'quests', 'events'])
        t.widget<Text>(find.byKey(Key('count-label-$k'))).style!.fontSize,
    };
    expect(sizes, hasLength(1), reason: 'кегли подписей: $sizes');
    // Телефон 26.11: подписи ужимались до 8–9 sp; прототип — 11. Не мельче 10.
    expect(sizes.single, greaterThanOrEqualTo(10), reason: 'кегль: $sizes');
    // Ни одна подпись не обрезана и не перенесена.
    for (final k in ['locations', 'items', 'characters', 'quests', 'events']) {
      final p = t.renderObject<RenderParagraph>(
        find.byKey(Key('count-label-$k')),
      );
      expect(p.didExceedMaxLines, isFalse, reason: k);
      expect(p.size.height, lessThan(20), reason: k);
    }
  });
}
