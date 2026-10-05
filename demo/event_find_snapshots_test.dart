// ПОКАЗ, а не проверка (5б+): событие видно с первого экрана мира — плитка в обзоре, раздел
// под местами, молния на карточке места, объяснение в пустом разделе, «Добавить событие»
// на странице места. В check.sh не входит.
// Запуск: flutter test --no-pub demo/event_find_snapshots_test.dart → build/snapshots/find-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/event_map_test.dart' show minesWithEvents;
import '../test/fakes.dart';
import '../test/place_page_test.dart' show nestedMines;
import 'shots.dart';

Future<void> openMines(WidgetTester t, FakeContent c) async {
  await t.runAsync(loadFont);
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpApp(t, content: c, wrap: frame);
  await signUp(t, 'author@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
}

Future<void> reach(WidgetTester t, String key) => t.scrollUntilVisible(
  find.byKey(Key(key)),
  120,
  scrollable: find.byType(Scrollable).first,
);

/// Раздел «События» целиком в кадре: его заголовок — у верха экрана.
Future<void> reachEvents(WidgetTester t) async {
  await reach(t, 'new-event');
  await Scrollable.ensureVisible(
    t.element(find.byKey(const Key('new-event'))),
    alignment: 0.12,
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('мир с событиями: обзор, карточки мест, раздел событий', (
    t,
  ) async {
    await openMines(t, await minesWithEvents());
    await shot(t, 'find-1-overview');
    await reach(t, 'open-zaboy');
    await shot(t, 'find-2-places');
    await reachEvents(t);
    await shot(t, 'find-3-events');

    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await t.pumpAndSettle();
    await reach(t, 'open-shtolnya_3');
    await tapShown(t, find.byKey(const Key('open-shtolnya_3')));
    await t.scrollUntilVisible(
      find.byKey(const Key('event-add')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, 'find-4-place');
  });

  testWidgets('мир без событий: раздел объясняет, что это', (t) async {
    await openMines(t, await nestedMines());
    await reachEvents(t);
    await shot(t, 'find-5-empty');

    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await t.pumpAndSettle();
    await reach(t, 'open-rynok');
    await tapShown(t, find.byKey(const Key('open-rynok')));
    await t.scrollUntilVisible(
      find.byKey(const Key('event-add')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await shot(t, 'find-6-place-empty');
  });
}
