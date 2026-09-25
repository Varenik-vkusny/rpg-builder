// ПОКАЗ, а не проверка: ассистент спрашивает автора, когда просьба спорит с правилами.
// Вопрос — дословно из живого прогона на Groq 25.09.2026 (live/shtolnya_scene_live_test.dart).
// Запуск: flutter test --no-pub demo/question_snapshots_test.dart → build/snapshots/q-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

const live = AuthorQuestion(
  'Вы хотите, чтобы в штольне жил утопленник уровня 3 с атакой 14, но такая атака '
  'превышает потолок (10) для уровня 3. Как поступить?',
  [
    (
      label: 'Снизить атаку до 10',
      description: 'Снизить атаку утопленника до допустимого максимума 10 (уровень 3, атака 10).',
    ),
    (
      label: 'Повысить уровень до 5',
      description:
          'Повысить уровень утопленника до 5 и верхний уровень локации до 5, '
          'чтобы атака 14 стала допустимой.',
    ),
  ],
);

void main() {
  testWidgets('вопрос ассистента → ответ → план', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    await pumpApp(
      t,
      content: await minesContent(),
      assistant: FakeAssistant([
        live,
        ...List.generate(3, (_) => proposal(floodPlan())),
      ]),
      wrap: frame,
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await tapShown(t, find.byKey(const Key('assistant-open')));
    await ask(
      t,
      request: 'Третья штольня затоплена. Теперь там живут утопленники 3 уровня с атакой 14.',
    );
    await shot(t, 'q-1-question');
    await tapShown(t, find.byKey(const Key('question-option-2')));
    await t.enterText(
      find.byKey(const Key('question-own')),
      'Уровень 3, атака 12 — пусть будет предупреждение',
    );
    await t.pump();
    await shot(t, 'q-2-own-answer');
  });
}
