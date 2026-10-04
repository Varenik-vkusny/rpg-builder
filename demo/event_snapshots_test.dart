// ПОКАЗ, а не проверка (5б): «Засада у лебёдки» в Штольне №3 — форма, страница, мир.
// В check.sh не входит.
// Запуск: flutter test --no-pub demo/event_snapshots_test.dart → build/snapshots/event-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/assistant_fixtures.dart';
import '../test/event_flow_test.dart' show choose;
import '../test/fakes.dart';
import 'shots.dart';

void main() {
  testWidgets('событие: форма, страница, список мира', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = await minesContent();
    await pumpApp(t, content: content, wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');

    // Раздел «События» — в конце ленивого списка мира: до него надо докрутить.
    Future<void> reach(String key) => t.scrollUntilVisible(
      find.byKey(Key(key)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await reach('new-event');
    await tapShown(t, find.byKey(const Key('new-event')));
    await t.enterText(find.byKey(const Key('event-title')), 'Засада у лебёдки');
    await t.enterText(
      find.byKey(const Key('event-description')),
      'Слизни падают с потолка, когда игрок берётся за рычаг.',
    );
    await choose(t, 'event-location', 'Штольня №3');
    await tapShown(t, find.byKey(const Key('event-enemy-add')));
    await choose(t, 'event-enemy-0', 'Слизень');
    await t.enterText(find.byKey(const Key('event-enemy-amount-0')), '3');
    await tapShown(t, find.byKey(const Key('event-item-add')));
    await choose(t, 'event-item-0', 'Ключ');
    await t.ensureVisible(find.byKey(const Key('event-save')));
    await t.pumpAndSettle();
    await shot(t, 'event-1-form');

    await tapShown(t, find.byKey(const Key('event-save')));
    final slug = (await content.events(minesId)).single.slug;
    await reach('open-$slug');
    await t.pumpAndSettle();
    await shot(t, 'event-2-world');

    await tapShown(t, find.byKey(Key('open-$slug')));
    await shot(t, 'event-3-page');
  });
}
