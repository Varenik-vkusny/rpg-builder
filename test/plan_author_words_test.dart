// План глазами автора: без служебного, без повторов, без ключей вида «location:rynok».
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_cards.dart';
import 'package:rpg_builder/ui/parts.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

void main() {
  testWidgets('карточки: нет повторов и служебных слов', (t) async {
    final j = floodPlanJson();
    (j['ops'] as List)[0]['repairs'] = ['опечатка в slug: a → b'];
    await openAssistant(
      t,
      FakeAssistant(List.generate(3, (_) => proposal(Plan.fromJson(j)))),
    );
    await ask(t);

    // Новый «Утопленник»: имя в шапке, а строки «Название — Утопленник» нет.
    final cards = find.byType(OpCard, skipOffstage: false);
    final drowned = find.descendant(
      of: cards,
      matching: find.text('Утопленник', skipOffstage: false),
    );
    expect(drowned, findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is BeforeAfter && w.label == 'Название',
        skipOffstage: false,
      ),
      findsNothing,
    );
    // Вид объекта — значком, серого слова рядом нет.
    for (final word in ['Персонаж', 'Квест']) {
      expect(
        find.descendant(
          of: cards,
          matching: find.text(word, skipOffstage: false),
        ),
        findsNothing,
        reason: word,
      );
    }
    expect(find.text('Удаляется целиком', skipOffstage: false), findsNothing);
    // Служебное и ключи.
    for (final bad in [
      'исправил сам',
      'Поправлено сервером',
      'опечатка в slug',
      'location:',
      'character:',
    ]) {
      expect(
        find.textContaining(bad, skipOffstage: false),
        findsNothing,
        reason: bad,
      );
    }
  });

  testWidgets('шторка проблем плана называется «Проверка»', (t) async {
    await openAssistant(
      t,
      FakeAssistant(List.generate(4, (_) => proposal(_broken))),
    );
    await ask(t);
    await openVerdict(t);
    expect(find.text('Проверка'), findsOneWidget);
    expect(find.textContaining('на копии мира'), findsNothing);
  });
}

const _broken = Plan(
  summary: 'Сломанный',
  ops: [
    PlanOp(
      action: OpAction.update,
      type: OpType.location,
      slug: 'net_takoy',
      fields: {'title': 'x'},
    ),
  ],
);
