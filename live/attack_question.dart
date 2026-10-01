// Прибор сцены 3.9 «ИИ спросил автора про атаку» — по смыслу, а не по числу (владелец, 26.09.2026):
// вопрос про атаку И (14, или потолок 10, или слова «максимум/потолок»). Смотрится текст вопроса
// вместе с вариантами ответа — модель часто кладёт числа в варианты.
import 'package:rpg_builder/assistant/assistant_service.dart';

bool askedAboutAttack(AuthorQuestion q) => askedAboutAttackText(
  [q.question, for (final o in q.options) '${o.label} ${o.description}'].join(' '),
);

/// То же по сырому тексту — для показа, где вопрос читается с экрана.
bool askedAboutAttackText(String raw) {
  final text = raw.toLowerCase();
  final aboutAttack = RegExp(r'атак|урон').hasMatch(text);
  final aboutCeiling =
      RegExp(r'(^|\D)1[04](\D|$)').hasMatch(text) ||
      RegExp(r'максим|потол|предел').hasMatch(text);
  return aboutAttack && aboutCeiling;
}
