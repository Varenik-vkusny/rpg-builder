// Правила дизайна (FEATURES 4½): ошибка ≠ предупреждение не только цветом, «было» не теряется.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/ui/parts.dart';
import 'package:rpg_builder/ui/theme.dart';

Future<void> _pump(WidgetTester t, Widget child, Brightness b) => t.pumpWidget(
  MaterialApp(
    theme: appTheme(b),
    home: Scaffold(body: child),
  ),
);

IconData? _iconIn(WidgetTester t, Finder f) =>
    t.widget<Icon>(find.descendant(of: f, matching: find.byType(Icon))).icon;

void main() {
  for (final b in Brightness.values) {
    testWidgets('ошибка и предупреждение различаются значком и словом ($b)', (
      t,
    ) async {
      await _pump(
        t,
        const Column(
          children: [
            NoticeBanner(Notice.error, 'вне области', key: Key('e')),
            NoticeBanner(Notice.warning, 'атака выше потолка', key: Key('w')),
            NoticeBanner(Notice.fix, 'опечатка', key: Key('f')),
          ],
        ),
        b,
      );
      final icons = {
        for (final k in ['e', 'w', 'f']) _iconIn(t, find.byKey(Key(k))),
      };
      expect(icons, hasLength(3), reason: 'у каждой плашки свой значок');
      for (final (k, word) in [
        ('e', 'Ошибка'),
        ('w', 'Предупреждение'),
        ('f', 'Поправлено сервером'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(k)),
            matching: find.textContaining(word),
          ),
          findsOneWidget,
          reason: 'плашка «$k» называет себя словом',
        );
      }
    });
  }

  testWidgets('«было» и «стало» видны оба, удаление и новое подписаны', (
    t,
  ) async {
    await _pump(
      t,
      const Column(
        children: [
          BeforeAfter(label: 'Атака', before: '14', after: '8'),
          BeforeAfter(label: 'Шанс', before: '35%', after: null),
          BeforeAfter(label: 'Роль', before: null, after: 'Враг'),
        ],
      ),
      Brightness.light,
    );
    for (final text in [
      '14',
      '8',
      'БЫЛО',
      'СТАЛО',
      '35%',
      'убрано',
      'НОВОЕ',
      'Враг',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('БЫЛО'), findsNWidgets(2));
  });

  testWidgets('метки изменения — три разных значка и слова', (t) async {
    await _pump(
      t,
      Row(children: [for (final c in Change.values) ChangeTag(c)]),
      Brightness.dark,
    );
    for (final c in Change.values) {
      expect(find.text(c.word), findsOneWidget);
    }
    expect({for (final c in Change.values) c.icon}, hasLength(3));
  });
}
