// Одно существо или предмет — одна строка в выдаче: SRD 5.1 (`srd_skeleton`) и SRD 5.2
// (`srd-2024_skeleton`) описывают одно и то же, остаётся свежее издание 5.2.
// Сопоставление — по сути: ключ без префикса издания. Сторонние книги не склеиваются.
import 'open5e_api.dart';

final _srdKey = RegExp(r'^(srd|srd-2024)_(.+)$');

/// Выдача без дублей между изданиями SRD; порядок — по первому появлению.
List<T> dedupeEditions<T>(List<T> found, String Function(T) keyOf) {
  final out = <T>[];
  final at = <String, int>{};
  for (final o in found) {
    final m = _srdKey.firstMatch(keyOf(o));
    if (m == null) {
      out.add(o);
      continue;
    }
    final slug = m.group(2)!;
    final i = at[slug];
    if (i == null) {
      at[slug] = out.length;
      out.add(o);
    } else if (m.group(1) == 'srd-2024') {
      out[i] = o;
    }
  }
  return out;
}

List<Open5eItem> dedupeItems(List<Open5eItem> l) =>
    dedupeEditions(l, (o) => o.key);
List<Open5eCreature> dedupeCreatures(List<Open5eCreature> l) =>
    dedupeEditions(l, (o) => o.key);

/// Русский поиск: справочник отдаёт находки по ключам в своём порядке — раскладываем
/// по рангу словаря (лучшие совпадения первыми), иначе при запасе на склейку лучшие
/// могли бы уйти за 20-е место. [keys] null — английский поиск, порядок справочника.
List<T> byKeyRank<T>(
  List<T> found,
  List<String>? keys,
  String Function(T) key,
) {
  if (keys == null) return found;
  final rank = {for (final (i, k) in keys.indexed) k: i};
  int r(T x) => rank[key(x)] ?? keys.length;
  final indexed = [...found.indexed]
    ..sort((a, b) {
      final c = r(a.$2).compareTo(r(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final (_, x) in indexed) x];
}
