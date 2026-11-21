// Прибор «план по шагам не сдвигает новые жетоны» (владелец 21.11): новые жетоны
// проступают сразу в тех клетках, где будут после «Применить». Раньше «Акула» на
// втором шаге вставала перед «Вепрем» (по названию) и сдвигала его; место, которое
// к концу плана становится широким, расширялось посреди показа и двигало соседей.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/content/location.dart';

import 'holst_build_test.dart' show settle;
import 'holst_change_test.dart' show ask, everyTry, k, mines;
import 'holst_fixture.dart';
import 'holst_look_test.dart' show token;

Plan beasts(String place, List<(String, String)> who) => Plan.fromJson({
  'summary': 'звери',
  'ops': [
    for (final (slug, title) in who)
      {
        'action': 'create',
        'type': 'character',
        'slug': slug,
        'fields': {'title': title, 'role': 'enemy', 'location': place},
      },
  ],
});

const three = [('vepr', 'Вепрь'), ('akula', 'Акула'), ('bes', 'Бес')];
const four = [...three, ('gul', 'Гуль')];

/// Прогон показа по шагам: каждый замер [watch] должен стоять, где впервые появился,
/// и остаться там же после «Применить».
Future<void> stepsStayPut(WidgetTester t, Map<String, Finder> watch) async {
  final canvas = t.getTopLeft(k('holst-canvas'));
  Rect at(Finder f) => t.getRect(f).shift(-canvas);
  await ask(t);
  final seen = <String, Rect>{};
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 300));
    for (final MapEntry(key: name, value: f) in watch.entries) {
      if (f.evaluate().isEmpty) continue;
      seen.putIfAbsent(name, () => at(f));
      expect(at(f), seen[name], reason: '$name сдвинулся на шаге');
    }
  }
  await settle(t);
  expect(seen.keys.toSet(), watch.keys.toSet());
  await t.tap(k('holst-plan-apply'));
  await settle(t);
  for (final MapEntry(key: name, value: f) in watch.entries) {
    expect(at(f), seen[name], reason: '$name после «Применить»');
  }
}

void main() {
  testWidgets('шаги плана: новые жетоны сразу на итоговых клетках', (t) async {
    final c = await mines();
    await pumpHolst(t, c, assistant: everyTry(beasts('shtolnya_3', three)));
    await stepsStayPut(t, {
      'Слизень': token('slizen'),
      for (final (slug, title) in three) title: token(slug),
    });
  });

  testWidgets(
    'шаги плана: Склад станет широким — на своём ряду и широкий с первого шага',
    (t) async {
      final c = await mines();
      // Склад — справа от Рынка в том же ряду; станет широким и уйдёт на новый ряд.
      await c.createLocation(
        holstWorld.id,
        const NewLocation(
          title: 'Склад',
          description: '',
          levelMin: 1,
          levelMax: 3,
        ),
      );
      await pumpHolst(t, c, assistant: everyTry(beasts('sklad', four)));
      await stepsStayPut(t, {
        'Рынок': k('hplace-rynok'),
        'Склад': k('hplace-sklad'),
        for (final (slug, title) in four) title: token(slug),
      });
    },
  );
}
