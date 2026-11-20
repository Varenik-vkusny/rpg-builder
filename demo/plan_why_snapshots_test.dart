// ПОКАЗ, а не проверка (владелец 20.11): план ассистента на холсте не применить —
// причина словами автора: «Гоблину-разведчику не задана роль».
// В check.sh не входит. Запуск: flutter test --no-pub demo/plan_why_snapshots_test.dart
// → build/snapshots/why-goblin.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';

import '../test/holst_change_test.dart' show ask, everyTry, mines;
import '../test/holst_fixture.dart';
import 'shots.dart';

void main() {
  testWidgets('план с персонажем без роли', (t) async {
    await t.runAsync(loadFont);
    final c = await mines();
    final plan = Plan.fromJson({
      'summary': 'гоблин',
      'ops': [
        {
          'action': 'create',
          'type': 'character',
          'slug': 'goblin_scout',
          'fields': {
            'title': 'Гоблин-разведчик',
            'role': null,
            'location': 'shtolnya_3',
          },
        },
      ],
    });
    await pumpHolst(
      t,
      c,
      assistant: everyTry(plan),
      size: const Size(360, 780),
      wrap: frame,
    );
    await ask(t);
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 2));
    await shot(t, 'why-goblin', ratio: 3);
  });
}
