// Правила для полей ввода, общие для всех форм: длина названия и вид почты.
// Те же границы стоят в базе; здесь автор узнаёт о них до отправки.

/// Столько знаков база принимает в названии мира и любого объекта.
const maxTitleLength = 120;

/// null — название годится; иначе — что сказать автору. [empty] — фраза формы
/// для пустого поля («Нужно название локации»).
String? titleError(String title, String empty) {
  if (title.isEmpty) return empty;
  final length = title.runes.length;
  if (length <= maxTitleLength) return null;
  return 'Слишком длинно: $length знаков, а можно не больше $maxTitleLength';
}

final _email = RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$');

/// Похоже ли на адрес почты: имя, «@», домен с точкой. Существует ли ящик — знает сервер.
bool looksLikeEmail(String text) => _email.hasMatch(text);
