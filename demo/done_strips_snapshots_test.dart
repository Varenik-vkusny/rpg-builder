// ПОКАЗ, а не проверка: все полосы «сделано» вида А одним листом, как в прототипе.
// Запуск: flutter test --no-pub demo/done_strips_snapshots_test.dart → build/snapshots/done-strips.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/gesture_path.dart';
import 'package:rpg_builder/map/holst_snack.dart';
import 'package:rpg_builder/ui/done_strip.dart';
import 'package:rpg_builder/ui/theme.dart';

import 'shots.dart';

void main() {
  testWidgets('все полосы «сделано» листом', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Widget strip(DoneKind k, String title, {String? sub}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DoneStrip(kind: k, title: title, sub: sub),
    );
    Widget snack(SnackData d) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HolstSnack(data: d),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: RepaintBoundary(
          key: frame,
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                strip(DoneKind.created, 'Создано: Враг 2'),
                strip(DoneKind.changed, 'Сохранено: Слизень'),
                strip(DoneKind.reverted, 'Набор откачен'),
                strip(DoneKind.deleted, 'Удалено: Слизень'),
                strip(DoneKind.applied, 'План применён'),
                strip(DoneKind.rejected, 'План отклонён'),
                strip(
                  DoneKind.error,
                  'Не удалось удалить',
                  sub: 'нет связи с сервером',
                ),
                const SizedBox(height: 8),
                snack(
                  SnackData(
                    title: 'Создано: Враг 2 в месте «Рынок»',
                    kind: DoneKind.created,
                    action: 'Отменить',
                    onAction: () {},
                  ),
                ),
                snack(
                  SnackData(
                    title: 'Перенесено: Слизень',
                    kind: DoneKind.changed,
                    action: 'Отменить',
                    onAction: () {},
                  ),
                ),
                snack(
                  SnackData(
                    title: 'Не перенесено',
                    sub: '«Забой» уже лежит внутри «Штольня №3»',
                    tone: GestureTone.error,
                    action: 'Понятно',
                    onAction: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await shot(t, 'done-strips', settle: false);
  });
}
