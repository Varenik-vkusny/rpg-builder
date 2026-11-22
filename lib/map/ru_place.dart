// Название места в предложном падеже для полосы «Создано: Житель 1 в Рынке».
// Эвристика, как dative в plan_why.dart: не уверен — null, тогда «в месте «Рынок»».
// Латиница, цифры, кавычки, незнакомые окончания и слова с особым «в лесу» — не склоняются.

/// «Рынок» → «Рынке», «Новое место» → «Новом месте», «Копи» → «Копях».
/// Не уверен в падеже — null.
String? prepositional(String name) {
  var words = name.trim().split(RegExp(r'\s+'));
  // Номер в конце не склоняется: «Штольня №3» → «Штольне №3», «Шахта 2» → «Шахте 2».
  var tail = <String>[];
  while (words.length > 1 && _number.hasMatch(words.last)) {
    tail = [words.removeLast(), ...tail];
  }
  if (words.isEmpty || words.first.isEmpty) return null;
  if (!RegExp(r'^[А-Яа-яЁё ]+$').hasMatch(words.join(' '))) return null;
  // Слово перед существительным — прилагательное; «-ые/-ие» говорит, что имя во мн. числе.
  final plural = words.any((w) => _isPluralAdj(w.toLowerCase()));
  final out = <String>[];
  for (final (i, w) in words.indexed) {
    final last = i == words.length - 1;
    final d = last ? _noun(w, plural: plural) : _adjective(w);
    if (d == null) return null;
    out.add(d);
  }
  return [...out, ...tail].join(' ');
}

final _number = RegExp(r'^(№\s?)?\d+$|^[IVX]+$');

/// Для полосы: «в Рынке»; падеж не угадать — «в месте «Рынок»».
String inPlace(String title) {
  final p = prepositional(title);
  return p == null ? 'в месте «$title»' : 'в $p';
}

bool _isPluralAdj(String l) =>
    l.length > 3 && (l.endsWith('ые') || l.endsWith('ие'));

String _cut(String w, int n, String add) => w.substring(0, w.length - n) + add;

String? _adjective(String w) {
  final l = w.toLowerCase();
  if (l.length < 4) return null;
  if (l.endsWith('ый') || l.endsWith('ой')) return _cut(w, 2, 'ом');
  if (l.endsWith('ий')) {
    return RegExp(r'[кгх]ий$').hasMatch(l)
        ? _cut(w, 2, 'ом')
        : _cut(w, 2, 'ем');
  }
  if (l.endsWith('ое')) return _cut(w, 2, 'ом');
  if (l.endsWith('ее')) return _cut(w, 2, 'ем');
  if (l.endsWith('яя')) return _cut(w, 2, 'ей');
  if (l.endsWith('ая')) {
    // «Горячая — в горячей», «Большая — в большой»: ударение, не угадать.
    return RegExp(r'[жшчщ]ая$').hasMatch(l) ? null : _cut(w, 2, 'ой');
  }
  if (l.endsWith('ые')) return _cut(w, 2, 'ых');
  if (l.endsWith('ие')) return _cut(w, 2, 'их');
  return null;
}

/// Мужские на согласный, где «беглая гласная» (рынок → в рынке): только проверенные.
const _fleeting = {
  'рынок': 'рынке',
  'замок': 'замке',
  'городок': 'городке',
  'посёлок': 'посёлке',
  'поселок': 'поселке',
  'островок': 'островке',
  'уголок': 'уголке',
  'переулок': 'переулке',
};

/// Мужские на -й: «в забое».
const _yWords = {
  'забой': 'забое',
  'бой': 'бое',
  'строй': 'строе',
  'рой': 'рое',
};

/// «В лесу», «в порту»: второй предложный — не угадать.
const _locative = {
  'лес',
  'сад',
  'луг',
  'мост',
  'берег',
  'угол',
  'бор',
  'ров',
  'порт',
  'мох',
  'лёд',
  'рай',
  'ад',
  'край',
  'дым',
  'пруд',
  'снег',
  'ряд',
  'лоб',
  'рот',
  'пол',
  'шкаф',
  'тыл',
  'плот',
  'год',
  'крым',
  'яр',
  'омут',
  'вход',
  'выход',
  'склон',
};

/// Неизменяемые и множественные на -а/-я: по одному слову не отличить от женского.
const _skip = {
  'метро',
  'кино',
  'пальто',
  'бюро',
  'такси',
  'леса',
  'города',
  'дома',
  'острова',
  'берега',
  'луга',
  'края',
  'стога',
  'снега',
  'поля',
  'моря',
  'вечера',
  'года',
};

const _hush = 'жчшщ';
const _cons = 'бвгджзклмнпрстфхцчшщ';
const _vowels = 'аеёиоуыэюя';

/// Слово, которое на самом деле прилагательное («Верхняя», «Золотой», «Тихие»).
bool _adjLike(String l) =>
    l.endsWith('ый') ||
    l.endsWith('ая') ||
    l.endsWith('яя') ||
    l.endsWith('ое') ||
    l.endsWith('ее') ||
    l.endsWith('ой') ||
    l.endsWith('ые') ||
    RegExp(r'[кгхжчшщ]ие$').hasMatch(l) ||
    (l.endsWith('ий') && l.length > 4 && 'кгхжчшщнл'.contains(l[l.length - 3]));

String? _noun(String w, {required bool plural}) {
  final l = w.toLowerCase();
  if (l.length < 3 || _skip.contains(l) || _locative.contains(l)) return null;
  if (_fleeting[l] ?? _yWords[l] case final f?) {
    // Слово заменено целиком — заглавную букву вернуть.
    return w[0] == w[0].toUpperCase() ? f[0].toUpperCase() + f.substring(1) : f;
  }
  if (_adjLike(l)) return _adjective(w);
  final last = l[l.length - 1], prev = l[l.length - 2];
  // Множественное: Бараки → Бараках, Шахты → Шахтах, Копи → Копях.
  if (last == 'ы' || (last == 'и' && _cons.contains(prev))) {
    final hard = last == 'ы' || 'кгх'.contains(prev) || _hush.contains(prev);
    return _cut(w, 1, hard ? 'ах' : 'ях');
  }
  if (plural && (last == 'а' || last == 'я')) {
    return _cut(w, 1, last == 'а' ? 'ах' : 'ях');
  }
  if (l.endsWith('ия') || l.endsWith('ие') || l.endsWith('ий')) {
    return _cut(w, 1, 'и');
  }
  if (l.endsWith('ея')) return _cut(w, 1, 'е');
  if (l.endsWith('ья') || l.endsWith('ью')) return null;
  if (l.endsWith('ье') || last == 'е') return w; // поле, ущелье: «в поле»
  if (last == 'а' || last == 'я' || last == 'о') {
    return _vowels.contains(prev) ? null : _cut(w, 1, 'е');
  }
  if (l.endsWith('ец')) return _cut(w, 2, 'це');
  if (_cons.contains(last) && !(l.endsWith('ок') || l.endsWith('ек'))) {
    return _cut(w, 0, 'е');
  }
  return null; // -ок, -ек, -ь, -й, латиница: не угадать
}
