// Вид А, срез 3: ошибки и предупреждения — цвет + значок + число (ячейки проверки).
// Прибор должен падать, если перепутать цвета, потерять число или слово степени.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rpg_builder/check/check_screen.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/ui/check_cells.dart';
import 'package:rpg_builder/ui/theme.dart';

Future<ThemeData> _pump(WidgetTester t, Widget body) async {
  final theme = appTheme(Brightness.dark);
  await t.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: body),
    ),
  );
  return theme;
}

/// Заливка ячейки: цвет её первого Container.
Color? _fill(WidgetTester t, String key) => t
    .widget<Container>(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Container),
          )
          .first,
    )
    .color;

Finder _in(String key, Finder f) =>
    find.descendant(of: find.byKey(Key(key)), matching: f);

void main() {
  testWidgets('полоса: ошибки красные, предупреждения жёлтые, с числами', (
    t,
  ) async {
    final theme = await _pump(t, const CheckStrip(errors: 2, warnings: 14));
    final warn = theme.extension<AppColors>()!.warn;
    expect(_fill(t, 'check-errors'), theme.colorScheme.error);
    expect(_fill(t, 'check-warnings'), warn);
    expect(_in('check-errors', find.text('2')), findsOneWidget);
    expect(_in('check-warnings', find.text('14')), findsOneWidget);
    expect(_in('check-errors', find.text('Ошибки')), findsOneWidget);
    expect(_in('check-warnings', find.text('Предупреждения')), findsOneWidget);
    expect(
      _in('check-errors', find.byIcon(Symbols.error_rounded)),
      findsOneWidget,
    );
    expect(
      _in('check-warnings', find.byIcon(Symbols.warning_rounded)),
      findsOneWidget,
    );
    final h = t.getSize(find.byType(CheckStrip)).height;
    expect(h, greaterThanOrEqualTo(60));
  });

  testWidgets('полоса: ноль — галка и число без заливки', (t) async {
    final theme = await _pump(t, const CheckStrip(errors: 0, warnings: 0));
    final ok = theme.extension<AppColors>()!.ok;
    for (final k in ['check-errors', 'check-warnings']) {
      expect(_fill(t, k), isNull, reason: '$k: ноль без заливки');
      expect(_in(k, find.text('0')), findsOneWidget);
      final tick = t.widget<Icon>(_in(k, find.byIcon(Symbols.check_rounded)));
      expect(tick.color, ok, reason: '$k: галка зелёная');
    }
    expect(find.byIcon(Symbols.error_rounded), findsNothing);
    expect(find.byIcon(Symbols.warning_rounded), findsNothing);
  });

  testWidgets('полоса: только ошибки — предупреждения спокойны', (t) async {
    final theme = await _pump(t, const CheckStrip(errors: 1, warnings: 0));
    expect(_fill(t, 'check-errors'), theme.colorScheme.error);
    expect(_fill(t, 'check-warnings'), isNull);
  });

  testWidgets('полоса: стрелка и нажатие — только с onTap; крупная ≥ 72', (
    t,
  ) async {
    var taps = 0;
    await _pump(
      t,
      CheckStrip(errors: 1, warnings: 1, big: true, onTap: () => taps++),
    );
    expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    expect(t.getSize(find.byType(CheckStrip)).height, greaterThanOrEqualTo(72));
    await t.tap(find.byType(CheckStrip));
    expect(taps, 1);
  });

  testWidgets('проблема: ячейка цвета тяжести и слово рядом со значком', (
    t,
  ) async {
    final theme = await _pump(
      t,
      Column(
        children: [
          ProblemRow(
            const Problem(Severity.error, 'x', 'a', 'нет выдающего'),
            key: const Key('e'),
            onFix: () {},
          ),
          ProblemRow(
            const Problem(Severity.warning, 'y', 'b', 'урон выше потолка'),
            key: const Key('w'),
            onFix: () {},
          ),
        ],
      ),
    );
    final warn = theme.extension<AppColors>()!.warn;
    Color? cell(String k) => t
        .widget<Container>(
          _in(
            k,
            find.byWidgetPredicate(
              (w) => w is Container && w.constraints?.maxWidth == 52,
            ),
          ),
        )
        .color;
    expect(cell('e'), theme.colorScheme.error);
    expect(cell('w'), warn);
    expect(_in('e', find.text('Ошибка')), findsOneWidget);
    expect(_in('w', find.text('Предупреждение')), findsOneWidget);
    expect(_in('e', find.text('Исправить')), findsOneWidget);
  });
}
