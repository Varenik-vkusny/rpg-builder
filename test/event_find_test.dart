// Событие видно и понятно с первого экрана мира (5б+, находка владельца 05.10: «не понял,
// в чём смысл событий и как их искать»): плитка в обзоре, раздел сразу под местами со строкой
// «где · кто · что», молния на карточке места, объяснение в пустом разделе, создание сцены
// прямо со страницы места.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/event_pages.dart';
import 'package:rpg_builder/ui/cover_card.dart';

import 'apply_flow_test.dart' show tapButton;
import 'event_map_test.dart' show minesWithEvents;
import 'fakes.dart';
import 'object_links_test.dart' show open;
import 'place_page_test.dart' show nestedMines, openWorldOf, worldId;

/// Высокий экран: список мира построен целиком.
Future<void> openTall(WidgetTester t, FakeContent c) async {
  t.view.physicalSize = const Size(800, 3200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await openWorldOf(t, c);
}

double top(WidgetTester t, Finder f) => t.getTopLeft(f).dy;

void main() {
  group('строка события', () {
    test('где сцена (путём) · кто и сколько · что лежит', () async {
      final w = await (await minesWithEvents()).snapshot(worldId);
      String line(String title) =>
          eventLine(w, w.events.firstWhere((e) => e.title == title));
      expect(line('Засада у лебёдки'), 'Копи › Штольня №3 · Слизень × 3');
      expect(line('Обвал кровли'), 'Копи › Штольня №3 › Забой');
    });

    test('события идут по местам: сначала по пути места, потом по названию', () async {
      final c = await minesWithEvents();
      final w0 = await c.snapshot(worldId);
      final market = w0.locations.firstWhere((l) => l.slug == 'rynok').id;
      for (final title in ['Ярмарка', 'Драка']) {
        await c.createEvent(
          worldId,
          NewEvent(title: title, description: '', locationId: market),
        );
      }
      final w = await c.snapshot(worldId);
      expect(
        [for (final e in eventsByPlace(w)) e.title],
        ['Засада у лебёдки', 'Обвал кровли', 'Драка', 'Ярмарка'],
      );
    });
  });

  testWidgets('обзор мира: плитка «События» с числом', (t) async {
    await openTall(t, await minesWithEvents());
    expect(
      find.descendant(
        of: find.byKey(const Key('count-events')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('count-events')),
        matching: find.text('События'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('раздел «События» — сразу под местами, выше предметов; в строке '
      '— где сцена и что в ней', (t) async {
    await openTall(t, await minesWithEvents());
    final events = top(t, find.byKey(const Key('new-event')));
    expect(events, greaterThan(top(t, find.byKey(const Key('new-location')))));
    expect(events, lessThan(top(t, find.byKey(const Key('new-item')))));
    // Последнее место в списке стоит выше раздела событий: раздел — под всеми местами.
    expect(events, greaterThan(top(t, find.byKey(const Key('open-rynok')))));

    expect(find.text('Копи › Штольня №3 · Слизень × 3'), findsOneWidget);
    expect(find.text('Копи › Штольня №3 › Забой'), findsOneWidget);
    expect(find.byKey(const Key('events-empty')), findsNothing);
  });

  testWidgets('мир без событий: раздел объясняет, что такое событие', (t) async {
    await openTall(t, await nestedMines());
    expect(
      find.descendant(
        of: find.byKey(const Key('events-empty')),
        matching: find.text(eventsHint),
      ),
      findsOneWidget,
    );
    expect(eventsHint, contains('сцена в месте'));
    expect(eventsHint, contains('Например'));
  });

  testWidgets('карточка места в списке: молния с числом — только сцены самого '
      'места', (t) async {
    await openTall(t, await minesWithEvents());
    List<Counter> counters(String slug) =>
        t.widget<CoverCard>(find.byKey(Key('open-$slug'))).counters;
    int? bolts(String slug) => [
      for (final (icon, n) in counters(slug))
        if (icon == Symbols.bolt_rounded) n,
    ].firstOrNull;
    // Сцена штольни — на карточке штольни; у Копей своих сцен нет — молнии нет.
    expect(bolts('shtolnya_3'), 1);
    expect(bolts('zaboy'), 1);
    expect(bolts('kopi'), isNull);
    expect(bolts('rynok'), isNull);
  });

  testWidgets('страница места без событий: объяснение и «Добавить событие» — '
      'форма уже знает место', (t) async {
    final c = await minesWithEvents();
    await openTall(t, c);
    await open(t, 'rynok');
    expect(find.text('События'), findsOneWidget);
    expect(find.text(eventsHint), findsOneWidget);

    await tapButton(t, 'event-add');
    expect(find.text('Новое событие'), findsOneWidget);
    // Место выбрано: остаётся назвать сцену.
    expect(
      find.descendant(
        of: find.byKey(const Key('event-location')),
        matching: find.text('Рынок'),
      ),
      findsOneWidget,
    );
    await t.enterText(find.byKey(const Key('event-title')), 'Ярмарка');
    await tapButton(t, 'event-save');

    final w = await c.snapshot(worldId);
    final fair = w.events.firstWhere((e) => e.title == 'Ярмарка');
    expect(w.titles[fair.locationId], 'Рынок');
    // Снова мир — и сцена уже в разделе событий.
    expect(find.text('Ярмарка'), findsOneWidget);
  });

  testWidgets('страница места с событиями: «Добавить событие» под сценами', (
    t,
  ) async {
    final c = await minesWithEvents();
    await openTall(t, c);
    await open(t, 'shtolnya_3');
    expect(find.text('События · 2'), findsOneWidget);
    await tapButton(t, 'event-add');
    expect(
      find.descendant(
        of: find.byKey(const Key('event-location')),
        matching: find.text('Штольня №3'),
      ),
      findsOneWidget,
    );
  });
}
