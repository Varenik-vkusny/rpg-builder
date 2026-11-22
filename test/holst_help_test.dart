// Прибор 5е.7 «Понятно без обучения»: подсказка при первом входе (3 строки, один раз),
// «?» — легенда цветов, нитей и жестов, пустой мир — три быстрых старта.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/holst_tags.dart' show EdgeArrowSample;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/open5e/open5e_screen.dart';

import 'fakes.dart';
import 'holst_build_test.dart' show settle, snack;
import 'holst_fixture.dart';
import 'open5e_enemy_test.dart' show creature;
import 'open5e_test.dart' show FakeOpen5e;

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

  testWidgets('«?» — легенда: цвета, объекты, метки, жесты', (t) async {
    await pumpHolst(t, await ashMines());
    await t.tap(k('help-screen-holst'));
    await t.pumpAndSettle();
    final sheet = k('help-sheet');
    for (final s in [
      'Легенда',
      'ЦВЕТА',
      'ОБЪЕКТЫ',
      'МЕТКИ',
      'ЖЕСТЫ',
      'Житель',
      'Враг',
      'Предмет',
      'Главное действие',
      'Изменено',
      'Новое',
      'Предупреждение',
      'Ошибка',
      'Связь выбранного',
      'Новая связь',
      'Изменённая связь',
      'Ещё связь — за краем',
      'Ещё связь — за дверью',
      'Значки — откуда связи',
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
    // Образцы рамок — те же формы, что на жетонах.
    for (final shape in ['round', 'spiky', 'square']) {
      expect(
        find.descendant(of: sheet, matching: k('legend-frame-$shape')),
        findsOneWidget,
        reason: shape,
      );
    }
    // «За краем» — та же стрелка, что на холсте, а не квадрат (владелец 19.11);
    // значки покоя тоже объяснены.
    for (final key in [
      'legend-edge-arrow',
      'legend-door-mark',
      'legend-badge',
    ]) {
      expect(find.descendant(of: sheet, matching: k(key)), findsOneWidget);
    }
    expect(
      t.widget<CustomPaint>(k('legend-edge-arrow')).painter,
      isA<EdgeArrowSample>(),
    );
  });

  testWidgets(
    'пустой мир — три старта; «Первое место» — создано через историю',
    (t) async {
      final c = FakeContent();
      await pumpHolst(t, c);
      expect(k('holst-empty'), findsOneWidget);
      expect(find.text('Из справочника'), findsOneWidget);
      expect(t.widget<InkWell>(k('holst-start-library')).onTap, isNotNull);
      await t.tap(k('holst-start-place'));
      await settle(t);
      expect(snack(t), 'Создано: Место 1');
      expect(c.journal.single.entry.request, 'Холст: создано «Место 1»');
      expect(k('holst-empty'), findsNothing);
      expect(k('hplace-mesto_1'), findsOneWidget);
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
      expect(t.widget<Text>(k('holst-scope')).data, 'Место 1');
    },
  );

  testWidgets('«Из справочника» открыт, без «позже»; «назад» — на холст', (
    t,
  ) async {
    await pumpHolst(t, FakeContent(), open5e: FakeOpen5e(const []));
    expect(find.text('позже'), findsNothing);
    await t.tap(k('holst-start-library'));
    await t.pumpAndSettle();
    expect(find.byType(Open5eScreen), findsOneWidget);
    expect(find.text('Образцы Open5e'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.byType(Open5eScreen), findsNothing);
    expect(k('holst-empty'), findsOneWidget);
    expect(find.text('Пустой мир'), findsOneWidget);
  });

  testWidgets(
    'справочник с холста: импорт врага — назад на холст, враг на полке',
    (t) async {
      final c = FakeContent();
      final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
      await pumpHolst(t, c, open5e: api);
      await t.tap(k('holst-start-library'));
      await t.pumpAndSettle();
      await t.tap(find.text('Враги'));
      await t.pumpAndSettle();
      await t.enterText(k('open5e-query'), 'skeleton');
      await t.tap(k('open5e-search'));
      await t.pumpAndSettle();
      await t.tap(k('open5e-srd_skeleton'));
      await t.pumpAndSettle();
      await t.tap(k('open5e-import'));
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Open5eScreen), findsNothing);
      final w = await c.snapshotOf(holstWorld.id);
      final e = w.characters.singleWhere((x) => x.slug == 'skeleton');
      expect(e.role, Role.enemy);
      expect(k('token-skeleton'), findsOneWidget);
      // Мир уже не пуст: заголовка нет, три старта остались.
      expect(find.text('Пустой мир'), findsNothing);
      expect(k('holst-start-place'), findsOneWidget);
      expect(k('holst-start-ask'), findsOneWidget);
      expect(k('holst-start-library'), findsOneWidget);
    },
  );
}
