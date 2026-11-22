// Прибор правила 11 для форм (найдено на телефоне 22.11): место, предмет, персонаж,
// квест и событие, созданные ФОРМОЙ в приложении, — набор «Создано вручную» в истории;
// откат набора убирает объект. Раньше форма писала мимо истории. Настоящая база —
// test/form_create_db_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'done_message_test.dart' show gone, quietMines;
import 'event_flow_test.dart' show choose;

void main() {
  testWidgets('пять форм — пять наборов «Создано вручную»; откат убирает', (
    t,
  ) async {
    final content = await quietMines(t);
    await tapButton(t, 'new-location');
    await t.enterText(find.byKey(const Key('location-title')), 'Причал');
    await tapButton(t, 'location-save');
    await gone(t);
    await tapButton(t, 'new-item');
    await t.enterText(find.byKey(const Key('item-title')), 'Лом');
    await t.enterText(find.byKey(const Key('item-stat')), '2');
    await tapButton(t, 'item-save');
    await gone(t);
    await tapButton(t, 'new-character');
    await t.enterText(find.byKey(const Key('character-title')), 'Сторож');
    await tapButton(t, 'character-save');
    await gone(t);
    await tapButton(t, 'new-event');
    await t.enterText(find.byKey(const Key('event-title')), 'Ярмарка');
    await choose(t, 'event-location', 'Рынок');
    await tapButton(t, 'event-save');
    await gone(t);
    await t.scrollUntilVisible(
      find.byKey(const Key('new-quest')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapButton(t, 'new-quest');
    await t.enterText(find.byKey(const Key('quest-title')), 'Смена');
    await choose(t, 'quest-giver', 'Бригадир');
    await choose(t, 'step-target-0-talk', 'Бригадир');
    await tapButton(t, 'quest-save');
    await gone(t);

    expect(
      [for (final j in content.journal) j.entry.request],
      [
        'Создано вручную: Причал',
        'Создано вручную: Лом',
        'Создано вручную: Сторож',
        'Создано вручную: Ярмарка',
        'Создано вручную: Смена',
      ],
    );
    // Откат последнего набора («Смена») — квеста нет, остальное на месте.
    final w0 = await content.snapshotOf(minesId);
    expect(w0.quests.any((q) => q.title == 'Смена'), isTrue);
    await content.revertChangeSet(minesId, content.journal.last.entry.id);
    final w = await content.snapshotOf(minesId);
    expect(w.quests.any((q) => q.title == 'Смена'), isFalse);
    expect(w.characters.any((c) => c.title == 'Сторож'), isTrue);
  });
}
