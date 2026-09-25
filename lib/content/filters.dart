// Фильтры списков мира (4.3): предметы — по редкости и виду, персонажи — по роли.
// Пустой выбор — показывать всех.
import 'character.dart';
import 'item.dart';

class ContentFilter {
  const ContentFilter({
    this.rarities = const {},
    this.kinds = const {},
    this.roles = const {},
  });

  final Set<Rarity> rarities;
  final Set<ItemKind> kinds;
  final Set<Role> roles;

  bool get isEmpty => rarities.isEmpty && kinds.isEmpty && roles.isEmpty;

  List<Item> items(List<Item> all) => [
    for (final i in all)
      if ((rarities.isEmpty || rarities.contains(i.rarity)) &&
          (kinds.isEmpty || kinds.contains(i.kind)))
        i,
  ];

  List<Character> characters(List<Character> all) => [
    for (final c in all)
      if (roles.isEmpty || roles.contains(c.role)) c,
  ];

  /// Выбор с переключённым значением: было — убрать, не было — добавить.
  static Set<T> toggle<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};

  ContentFilter copyWith({
    Set<Rarity>? rarities,
    Set<ItemKind>? kinds,
    Set<Role>? roles,
  }) => ContentFilter(
    rarities: rarities ?? this.rarities,
    kinds: kinds ?? this.kinds,
    roles: roles ?? this.roles,
  );
}
