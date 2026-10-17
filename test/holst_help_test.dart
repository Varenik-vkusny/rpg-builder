// Прибор 5е.7 «Понятно без обучения»: подсказка при первом входе (3 строки, один раз),
// «?» — легенда цветов, нитей и жестов, пустой мир — три быстрых старта.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';
import 'holst_build_test.dart' show settle, snack;
import 'holst_fixture.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  testWidgets(
    'первый вход — подсказка в 3 строки; «Понятно» — больше не показывается',
    (t) async {
      await pumpHolst(t, await ashMines(), coachSeen: false);
      expect(k('holst-coach'), findsOneWidget);
      for (final l in [
        'Нажми объект — увидишь связи',
        'Два пальца — ближе, дальше',
        '«Строить» — тащи и соединяй',
      ]) {
        expect(find.text(l), findsOneWidget);
      }
      await t.tap(k('holst-coach-ok'));
      await t.pumpAndSettle();
      expect(k('holst-coach'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getBool('holst-coach'),
        isTrue,
      );
      // Второй вход — без подсказки (хранилище то же).
      final c = await ashMines();
      await t.pumpWidget(const SizedBox());
      final snapshot = await c.snapshotOf(holstWorld.id);
      expect(snapshot.locations, isNotEmpty);
      await pumpHolstKeepPrefs(t, c);
      expect(k('holst-coach'), findsNothing);
    },
  );

  testWidgets('«?» — легенда: цвета, нити, жесты', (t) async {
    await pumpHolst(t, await ashMines());
    await t.tap(k('help-screen-holst'));
    await t.pumpAndSettle();
    final sheet = k('help-sheet');
    for (final s in [
      'Легенда',
      'ЦВЕТА',
      'НИТИ',
      'ЖЕСТЫ',
      'Главное действие',
      'Изменено',
      'Новое',
      'Предупреждение',
      'Ошибка',
      'Связь',
      'Добыча',
      'Выбрано',
      'Из палитры в место — создать',
      'От объекта к объекту — связь',
      'Держать и тащить — перенести',
      'Отменить — 5 секунд после жеста',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(s)),
        findsWidgets,
        reason: s,
      );
    }
  });

  testWidgets(
    'пустой мир — три старта; «Первое место» — создано через историю',
    (t) async {
      final c = FakeContent();
      await pumpHolst(t, c);
      expect(k('holst-empty'), findsOneWidget);
      expect(find.text('Из справочника'), findsOneWidget);
      expect(t.widget<InkWell>(k('holst-start-library')).onTap, isNull);
      await t.tap(k('holst-start-place'));
      await settle(t);
      expect(snack(t), 'Создано: Новое место');
      expect(c.journal.single.entry.request, 'Холст: создано «Новое место»');
      expect(k('holst-empty'), findsNothing);
      expect(k('hplace-novoe_mesto'), findsOneWidget);
    },
  );

  testWidgets(
    'пустой мир — «Попросить ассистента»: место и сразу «Менять» с ним',
    (t) async {
      final c = FakeContent();
      await pumpHolst(t, c);
      await t.tap(k('holst-start-ask'));
      await settle(t);
      expect(k('holst-phrase'), findsOneWidget);
      expect(t.widget<Text>(k('holst-scope')).data, 'Новое место');
    },
  );
}
