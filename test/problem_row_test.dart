// Проверка мира (FEATURES 4½): ошибка и предупреждение различаются значком И словом, не только цветом.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/check_screen.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/ui/theme.dart';

void main() {
  for (final b in Brightness.values) {
    testWidgets('строка проблемы: значок и слово по степени ($b)', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: appTheme(b),
          home: Scaffold(
            body: Column(
              children: [
                ProblemRow(
                  const Problem(Severity.error, 'x', 'a', 'нет выдающего'),
                  key: const Key('e'),
                  onFix: () {},
                ),
                ProblemRow(
                  const Problem(
                    Severity.warning,
                    'y',
                    'b',
                    'урон выше потолка',
                  ),
                  key: const Key('w'),
                  onFix: () {},
                ),
              ],
            ),
          ),
        ),
      );
      IconData icon(String k) => t
          .widget<Icon>(
            find
                .descendant(
                  of: find.byKey(Key(k)),
                  matching: find.byWidgetPredicate(
                    (w) => w is Icon && w.icon != null,
                  ),
                )
                .first,
          )
          .icon!;
      expect(icon('e'), isNot(icon('w')), reason: 'разные значки');
      for (final (k, word) in [('e', 'Ошибка'), ('w', 'Предупреждение')]) {
        expect(
          find.descendant(of: find.byKey(Key(k)), matching: find.text(word)),
          findsOneWidget,
          reason: 'строка «$k» называет степень словом',
        );
      }
    });
  }
}
