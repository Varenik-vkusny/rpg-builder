// Причина «Не получится» в плане холста — словами автора (владелец 20.11):
// не «Операция 1 (Создать · Персонаж «Гоблин-разведчик»): не задано: роль»,
// а «Гоблину-разведчику не задана роль». Текст проверки, который читает ассистент
// и экран проверки, не меняется — здесь только то, что видит автор на холсте.
import '../assistant/plan_labels.dart' show splitOpTitle;
import '../assistant/plan_preview.dart';
import '../check/world_check.dart';

/// Первая ошибка плана словами автора; null — ошибок нет.
String? planWhy(PlanPreview p) {
  final e = p.of(Severity.error).firstOrNull;
  if (e == null) return null;
  final i = e.objectId.startsWith('op-')
      ? int.tryParse(e.objectId.substring(3))
      : null;
  // Ошибка мира после плана — проверка и так пишет её словами («у квеста нет шагов»).
  if (i == null || i >= p.ops.length) return e.message;
  final name = splitOpTitle(p.ops[i].title).$3;
  if (e.rule == 'out_of_scope') return _up('$name — не из выбранного');
  return opWhy(name, p.ops[i].error ?? '');
}

final _missing = RegExp(r'^не задано: (.+)$');
final _absent = RegExp(r'^(\S+) «([^»]*)» нет в мире$');

/// Ошибка одной операции: [name] — то, что она меняет; [error] — текст проверки.
String opWhy(String name, String error) {
  final missing = _missing.firstMatch(error);
  if (missing != null) {
    final to = dative(name);
    final what = rowWhy(error);
    return to == null ? _up('$what: $name') : '$to $what';
  }
  final absent = _absent.firstMatch(error);
  // Нет самого объекта — его «имя» и есть ключ ассистента, автору его не показываем.
  if (absent != null && absent.group(2) == name) return _up(rowWhy(error));
  if (error.endsWith('уже занят')) return _up('$name ${rowWhy(error)}');
  return _up('$name: ${rowWhy(error)}');
}

/// Та же ошибка без имени — под строкой плана, где имя уже написано:
/// «не задана роль», «в мире нет такого места», «уже есть в мире».
String rowWhy(String error) {
  final missing = _missing.firstMatch(error);
  if (missing != null) {
    final what = missing.group(1)!;
    return 'не ${_set[what] ?? 'задано'} $what';
  }
  final absent = _absent.firstMatch(error);
  if (absent != null) {
    return 'в мире нет такого ${_kind[absent.group(1)] ?? 'объекта'}';
  }
  if (error.startsWith('slug ')) {
    return error.endsWith('уже занят')
        ? 'уже есть в мире'
        : 'ассистент ошибся в записи — попроси ещё раз';
  }
  return error;
}

/// «роль» → «задана»: род слова, которого не хватает.
const _set = {
  'роль': 'задана',
  'защита': 'задана',
  'цена': 'задана',
  'редкость': 'задана',
  'имя': 'задано',
  'название': 'задано',
  'уровни': 'заданы',
  'вид': 'задан',
  'урон': 'задан',
  'уровень': 'задан',
};

/// Родительный падеж вида из текста проверки («локации» → «места»).
const _kind = {
  'локации': 'места',
  'предмета': 'предмета',
  'персонажа': 'персонажа',
  'события': 'события',
  'квеста': 'квеста',
};

String _up(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Имя в дательном падеже: «Гоблин-разведчик» → «Гоблину-разведчику»,
/// «Старый бригадир» → «Старому бригадиру». Не уверен — null (тогда без падежа).
String? dative(String name) {
  if (name.isEmpty || name.contains('«') || name.contains('→')) return null;
  final words = name.split(' ');
  final out = <String>[];
  for (final (wi, w) in words.indexed) {
    final last = wi == words.length - 1;
    final parts = w.split(RegExp(r'(?<=[-‑])'));
    final done = <String>[];
    for (final part in parts) {
      final hyphen = part.endsWith('-') || part.endsWith('‑');
      final word = hyphen ? part.substring(0, part.length - 1) : part;
      final d = _dativeWord(word, noun: last || hyphen);
      if (d == null) return null;
      done.add(hyphen ? '$d${part[part.length - 1]}' : d);
    }
    out.add(done.join());
  }
  return out.join(' ');
}

final _cyr = RegExp(r'[а-яё]', caseSensitive: false);
const _consonants = 'бвгджзклмнпрстфхцчшщ';

/// Одно слово: [noun] — последнее в имени (сущ.), иначе — прилагательное.
String? _dativeWord(String w, {required bool noun}) {
  // «№3», латиница — не склоняются.
  if (w.isEmpty || !w.contains(_cyr)) return w;
  final l = w.toLowerCase();
  String cut(int n, String add) => w.substring(0, w.length - n) + add;
  bool ends(String s) => l.endsWith(s);
  if (!noun) {
    if (ends('ый') || ends('ой')) return cut(2, 'ому');
    if (ends('кий') || ends('гий') || ends('хий')) return cut(2, 'ому');
    if (ends('ий')) return cut(2, 'ему');
    if (ends('ое')) return cut(2, 'ому');
    if (ends('ее')) return cut(2, 'ему');
    if (ends('яя')) return cut(2, 'ей');
    if (ends('ая')) {
      return RegExp(r'[жшчщ]ая$').hasMatch(l) ? null : cut(2, 'ой');
    }
    if (ends('ые') || ends('ие')) return null;
  }
  // Беглая гласная («купец → купцу», «волчок → волчку») и «ь» (конь/тень) — не угадать.
  if (ends('ец') || ends('ок') || ends('ек') || ends('ёк') || ends('ь')) {
    return null;
  }
  if (ends('ий')) return cut(1, 'ю');
  if (ends('ия')) return cut(1, 'и');
  if (ends('й')) return cut(1, 'ю');
  if (ends('а') || ends('я')) return cut(1, 'е');
  // Множественное («копи») — не угадать.
  if (ends('ы') || ends('и')) return null;
  if (_consonants.contains(l[l.length - 1])) return '$wу';
  return w; // «Эхо», «кафе» — не склоняются
}
