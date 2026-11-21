// Порядок созданного планом в копии мира — как его отдаст база (часть plan_apply.dart).
part of 'plan_apply.dart';

/// Созданное планом — в конце списка по названию: в базе у него одно время создания,
/// и она отдаёт его по названию (content_repo.dart) — иначе после «Применить» новые
/// жетоны менялись бы местами с предпросмотром.
void _byTitle<T>(
  List<T> list,
  Set<String> was,
  String Function(T) id,
  String Function(T) title,
) {
  final fresh = [
    for (final x in list)
      if (!was.contains(id(x))) x,
  ]..sort((a, b) => titleOrder(title(a), title(b)));
  list
    ..removeWhere((x) => !was.contains(id(x)))
    ..addAll(fresh);
}

final _notWord = RegExp(r'[^\p{L}\p{N}]', unicode: true);

/// Сравнение названий как у базы (языковое правило): без регистра, «ё» как «е»,
/// пробелы и знаки — только при равенстве букв, строчная раньше заглавной. Приближение: экзотику (лигатуры,
/// редкие алфавиты) база может упорядочить иначе.
int titleOrder(String a, String b) {
  String key(String s) =>
      s.toLowerCase().replaceAll('ё', 'е').replaceAll(_notWord, '');
  final k = key(a).compareTo(key(b));
  if (k != 0) return k;
  final l = a.toLowerCase().compareTo(b.toLowerCase());
  // Различие только в регистре — строчная первой («рог» раньше «Рог»), как у базы.
  return l != 0 ? l : b.compareTo(a);
}

extension _Order on _Copy {
  void newByTitle(WorldSnapshot w) {
    _byTitle(
      locations,
      {for (final x in w.locations) x.id},
      (x) => x.id,
      (x) => x.title,
    );
    _byTitle(
      items,
      {for (final x in w.items) x.id},
      (x) => x.id,
      (x) => x.title,
    );
    _byTitle(
      characters,
      {for (final x in w.characters) x.id},
      (x) => x.id,
      (x) => x.title,
    );
    _byTitle(
      quests,
      {for (final x in w.quests) x.id},
      (x) => x.id,
      (x) => x.title,
    );
    _byTitle(
      events,
      {for (final x in w.events) x.id},
      (x) => x.id,
      (x) => x.title,
    );
  }
}
