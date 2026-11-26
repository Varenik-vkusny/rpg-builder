// Полоса «сделано» вида А («Лист»): графитовая, слева цветная ячейка действия;
// отказ — красная, причина одной строкой. Вид задаётся параметром, а не текстом.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rpg_builder/map/gesture_path.dart';
import 'package:rpg_builder/map/holst_snack.dart';
import 'package:rpg_builder/ui/messages.dart';
import 'package:rpg_builder/ui/palettes.dart';
import 'package:rpg_builder/ui/theme.dart';

final _theme = appTheme(Brightness.dark);
final _s = _theme.colorScheme;
final _c = AppColors.from(darkPalette);
const _done = Key('done-message');

Future<void> pumpDone(
  WidgetTester t,
  String text,
  DoneKind kind, {
  String? sub,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => showDone(c, text, kind, sub: sub),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pump();
}

/// Ячейка действия полосы: цвет фона и значок со своим цветом.
({Color bg, IconData? icon, Color? fg}) cell(WidgetTester t) {
  final box = find.byKey(const Key('done-cell'));
  expect(box, findsOneWidget, reason: 'нет ячейки действия');
  final bg = t.widget<Container>(box).color ?? Colors.transparent;
  final icon = t.widget<Icon>(
    find.descendant(of: box, matching: find.byType(Icon)),
  );
  return (bg: bg, icon: icon.icon, fg: icon.color);
}

Finder body(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(Material));

Future<void> pumpSnack(WidgetTester t, SnackData d) => t.pumpWidget(
  MaterialApp(
    theme: _theme,
    home: Scaffold(body: HolstSnack(data: d)),
  ),
);

void main() {
  testWidgets('создано: ячейка зелёная со значком «+», 48 dp, полоса от 52', (
    t,
  ) async {
    await pumpDone(t, 'Создано: Кирка', DoneKind.created);
    final x = cell(t);
    expect(x.bg, _c.okContainer);
    expect(x.fg, _c.ok);
    expect(x.icon, Symbols.add_rounded);
    expect(t.getSize(find.byKey(const Key('done-cell'))).width, 48);
    expect(t.getSize(find.byKey(_done)).height, greaterThanOrEqualTo(52));
  });

  testWidgets('сохранено: ячейка пурпурная со значком «карандаш»', (t) async {
    await pumpDone(t, 'Сохранено: Кирка', DoneKind.changed);
    final x = cell(t);
    expect(x.bg, _c.changeContainer);
    expect(x.fg, _c.change);
    expect(x.icon, Symbols.edit_rounded);
  });

  testWidgets('удалено: ячейка серая, без цвета действия', (t) async {
    await pumpDone(t, 'Удалено: Кирка', DoneKind.deleted);
    final x = cell(t);
    expect(x.fg, _s.onSurfaceVariant);
    expect(x.bg, Colors.transparent);
    expect(x.icon, Symbols.remove_rounded);
  });

  testWidgets('откат: значок белый, как основной текст', (t) async {
    await pumpDone(t, 'Набор откачен', DoneKind.reverted);
    expect(cell(t).fg, _s.onSurface);
    expect(cell(t).icon, Symbols.undo_rounded);
  });

  testWidgets('фон графитовый, а не светлая плашка; рамка outline', (t) async {
    await pumpDone(t, 'Создано: Кирка', DoneKind.created);
    final m = t.widget<Material>(body(_done).first);
    expect(m.color, _s.surfaceContainerHighest);
    expect(m.color, isNot(_s.inverseSurface));
    expect((m.shape! as Border).top.color, _s.outline);
  });

  testWidgets('ошибка: красная полоса, причина одной строкой мелко', (t) async {
    await pumpDone(
      t,
      'Не удалось удалить',
      DoneKind.error,
      sub: 'Нет связи с сервером, ' * 12,
    );
    final m = t.widget<Material>(body(_done).first);
    expect(m.color, _s.errorContainer);
    expect((m.shape! as Border).top.color, _s.error);
    final x = cell(t);
    expect(x.bg, _s.error);
    expect(x.icon, Symbols.priority_high_rounded);
    final why = find.descendant(
      of: find.byKey(_done),
      matching: find.textContaining('Нет связи'),
    );
    final text = t.widget<Text>(why);
    expect(text.maxLines, 1);
    expect(
      t.getSize(why).height,
      lessThan(20),
      reason: 'причина в несколько строк',
    );
    expect(text.style!.color, _s.onErrorContainer);
    expect(text.style!.fontSize, lessThan(15));
  });

  testWidgets('полоса холста: отказ — красная, причина в одну строку', (
    t,
  ) async {
    await pumpSnack(
      t,
      SnackData(
        title: 'Не перенесено',
        sub: 'Очень длинная причина отказа, ' * 8,
        tone: GestureTone.error,
        action: 'Понятно',
        onAction: () {},
      ),
    );
    final why = find.byKey(const Key('holst-snack-sub'));
    expect(t.getSize(why).height, lessThan(20));
    final m = t.widget<Material>(body(const Key('holst-snack')).first);
    expect(m.color, _s.errorContainer);
  });

  testWidgets('полоса холста: создано — зелёная «+», правка — пурпурная', (
    t,
  ) async {
    for (final (kind, bg, icon) in [
      (DoneKind.created, _c.okContainer, Symbols.add_rounded),
      (DoneKind.changed, _c.changeContainer, Symbols.edit_rounded),
    ]) {
      await pumpSnack(
        t,
        SnackData(
          title: 'Готово',
          kind: kind,
          action: 'Отменить',
          onAction: () {},
        ),
      );
      expect(cell(t).bg, bg);
      expect(cell(t).icon, icon);
      expect(find.text('Отменить'), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
    }
  });
}
