/// slug — постоянное имя объекта для ссылок и экспорта (латиница, цифры, `_`).
/// Назначается один раз при создании и больше не меняется (VISION.md, правило 8).
const _translit = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'e',
  'ё': 'e',
  'ж': 'zh',
  'з': 'z',
  'и': 'i',
  'й': 'y',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ф': 'f',
  'х': 'kh',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'shch',
  'ъ': '',
  'ы': 'y',
  'ь': '',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};

/// «Штольня №3» → `shtolnya_3`. Пустой результат → `object`.
String slugify(String title) {
  final buf = StringBuffer();
  for (final ch in title.toLowerCase().split('')) {
    final t = _translit[ch];
    if (t != null) {
      buf.write(t);
    } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
      buf.write(ch);
    } else {
      buf.write('_');
    }
  }
  final slug = buf
      .toString()
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? 'object' : slug;
}

/// slug, не совпадающий с уже занятыми в мире: `shtolnya_3`, `shtolnya_3_2`, …
String uniqueSlug(String title, Iterable<String> taken) {
  final base = slugify(title);
  final used = taken.toSet();
  if (!used.contains(base)) return base;
  var n = 2;
  while (used.contains('${base}_$n')) {
    n++;
  }
  return '${base}_$n';
}
