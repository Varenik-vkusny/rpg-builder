// Прибор текстов справки: коротко и без воды (требование владельца 03.10).
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/warning_rules.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/help/help_texts.dart';

/// Вступления и слова-пустышки.
final _water = RegExp(
  r'это поле|позволяет|здесь вы|вы можете|просто|легко|удобн',
  caseSensitive: false,
);

/// Одна фраза: точка только в конце (пояснение «Потом не меняется.» — вторая, короткая).
int _sentences(String s) => RegExp(r'[.!?](\s|$)').allMatches(s).length;

void main() {
  test('текст поля: не длиннее $fieldHelpLimit знаков вместе с примером', () {
    final long = [
      for (final e in fieldHelp.entries)
        if (e.value.text.length > fieldHelpLimit)
          '${e.key}: ${e.value.text.length} — «${e.value.text}»',
    ];
    expect(long, isEmpty, reason: long.join('\n'));
  });

  test('текст поля: без вступлений, пустых слов и повтора названия поля', () {
    final bad = <String>[];
    for (final e in fieldHelp.entries) {
      final h = e.value;
      final word = h.title.split(RegExp(r'[ ,]')).first.toLowerCase();
      if (_water.hasMatch(h.text)) bad.add('${e.key}: вода — «${h.text}»');
      if (h.what.toLowerCase().contains(word)) {
        bad.add('${e.key}: повтор названия «${h.title}» — «${h.what}»');
      }
      if (h.what.isEmpty || h.example.isEmpty) bad.add('${e.key}: пусто');
      if (_sentences(h.what) > 2) bad.add('${e.key}: больше двух фраз');
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  // Числа в справке взяты из правил проверки. Поменяется правило — справка соврёт молча.
  test('числа в текстах совпадают с правилами проверки', () {
    expect(attackCeiling(1), 4 + 1 * 2, reason: 'character.attack: формула');
    expect(attackCeiling(3), 10, reason: 'character.attack: пример');
    expect(
      damageCeiling(3, Rarity.rare),
      13,
      reason: 'item.level, item.damage',
    );
    expect(fieldHelp['character.attack']!.what, contains('4 + уровень × 2'));
    expect(fieldHelp['character.attack']!.example, contains('10'));
    expect(fieldHelp['item.level']!.example, contains('13'));
    expect(fieldHelp['item.damage']!.example, contains('13'));
  });

  test('текст экрана: от 1 до 3 строк, каждая — одна фраза без воды', () {
    final bad = <String>[];
    for (final e in screenHelp.entries) {
      final lines = e.value.lines;
      if (lines.isEmpty || lines.length > 3) {
        bad.add('${e.key}: строк ${lines.length}');
      }
      for (final l in lines) {
        if (_water.hasMatch(l)) bad.add('${e.key}: вода — «$l»');
        if (_sentences(l) > 1) bad.add('${e.key}: не одна фраза — «$l»');
        if (l.length > fieldHelpLimit) bad.add('${e.key}: длинно — «$l»');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
