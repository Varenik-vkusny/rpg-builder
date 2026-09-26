// Прибор: прочитает ли файл JsonUtility Unity. Пусто — прочитает; иначе — что мешает.
// JsonUtility разбирает только классы C#: поля с именами-идентификаторами, массивы простых
// значений или объектов одного класса. Словарь (ключ = данные, например slug) он не читает,
// null у int не бывает, массив массивов не поддерживается.
final _ident = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

List<String> jsonUtilityProblems(Object? root) {
  final out = <String>[];
  if (root is! Map) return ['корень не объект'];
  if (root['schemaVersion'] is! int) {
    out.add('нет целого schemaVersion в корне');
  }
  final slugs = <String>{};
  void collectSlugs(Object? v) {
    if (v is Map) {
      if (v['slug'] is String) slugs.add(v['slug'] as String);
      v.values.forEach(collectSlugs);
    } else if (v is List) {
      v.forEach(collectSlugs);
    }
  }

  collectSlugs(root);
  // Один путь — один класс C#: у всех объектов на пути одинаковые поля.
  final shapes = <String, Set<String>>{};
  void walk(Object? v, String path) {
    if (v == null) {
      out.add('$path: null');
    } else if (v is Map) {
      final keys = {for (final k in v.keys) k as String};
      for (final k in keys) {
        if (!_ident.hasMatch(k)) out.add('$path: ключ «$k» не имя поля C#');
        if (slugs.contains(k)) {
          out.add('$path: ключ «$k» — это slug, похоже на словарь');
        }
      }
      final seen = shapes.putIfAbsent(path, () => keys);
      if (seen.length != keys.length || !seen.containsAll(keys)) {
        out.add(
          '$path: у объектов разные поля ($seen и $keys) — похоже на словарь',
        );
      }
      for (final e in v.entries) {
        walk(e.value, '$path.${e.key}');
      }
    } else if (v is List) {
      for (final e in v) {
        if (e is List) out.add('$path: массив массивов');
        walk(e, '$path[]');
      }
    }
  }

  walk(root, r'$');
  return out;
}
