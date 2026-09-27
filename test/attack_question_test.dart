// Прибор сцены 3.9 «ИИ спросил про атаку» (live/attack_question.dart) — умеет краснеть.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';

import '../live/attack_question.dart';

AuthorQuestion q(String text, [List<String> options = const []]) =>
    AuthorQuestion(text, [
      for (final o in options) (label: o, description: ''),
    ]);

void main() {
  test(
    'вопрос про атаку: 14, потолок 10 или слова «максимум/потолок» — засчитан',
    () {
      expect(
        askedAboutAttack(q('Атака 14 выше потолка. Что сделать?')),
        isTrue,
      );
      expect(
        askedAboutAttack(
          q('Скорректировать атаку?', ['Снизить до максимума 10']),
        ),
        isTrue,
      );
      expect(
        askedAboutAttack(q('Атака выше допустимого потолка уровня. Как быть?')),
        isTrue,
      );
      expect(
        askedAboutAttack(q('Какую атаку оставить?', ['10', 'Своя'])),
        isTrue,
      );
    },
  );

  test('вопрос про атаку: вопрос не про атаку — красный', () {
    expect(
      askedAboutAttack(q('Сколько утопленников поселить: 10 или 14?')),
      isFalse,
    );
    expect(
      askedAboutAttack(
        q('Удалить слизней или переселить?', ['Удалить', 'Переселить']),
      ),
      isFalse,
    );
  });

  test('вопрос про атаку: про атаку, но без потолка и чисел — красный', () {
    expect(askedAboutAttack(q('Атака утопленника — какая?')), isFalse);
    expect(askedAboutAttack(q('Атака 140?')), isFalse);
  });
}
