// ПОКАЗ, а не проверка: пустой мир — третий старт «Из справочника» открыт; справочник;
// после импорта врага — холст с ним. Запуск: flutter test --no-pub demo/holst_library_snapshots_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/fakes.dart';
import '../test/holst_fixture.dart';
import '../test/open5e_enemy_test.dart' show creature;
import '../test/open5e_test.dart' show FakeOpen5e;
import 'shots.dart';

Finder k(String key) => find.byKey(Key(key));

void main() {
  testWidgets('справочник с пустого холста', (t) async {
    await t.runAsync(loadFont);
    final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
    await pumpHolst(
      t,
      FakeContent(),
      wrap: frame,
      size: const Size(360, 760),
      open5e: api,
    );
    await shot(t, 'lib-1-start', ratio: 2);
    await t.tap(k('holst-start-library'));
    await t.pumpAndSettle();
    await t.tap(find.text('Враги'));
    await t.pumpAndSettle();
    await t.enterText(k('open5e-query'), 'skeleton');
    await t.tap(k('open5e-search'));
    await shot(t, 'lib-2-library', ratio: 2);
    await t.tap(k('open5e-srd_skeleton'));
    await t.pumpAndSettle();
    await t.tap(k('open5e-import'));
    await t.pump(const Duration(milliseconds: 600));
    await shot(t, 'lib-3-after', ratio: 2, settle: false);
  });
}
