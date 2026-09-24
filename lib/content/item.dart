/// Тип предмета. Урон есть только у оружия, защита — только у брони.
enum ItemKind {
  weapon('Оружие'),
  armor('Броня'),
  consumable('Расходник'),
  quest('Квестовый'),
  misc('Прочее');

  const ItemKind(this.label);
  final String label;
}

enum Rarity {
  common('Обычный'),
  uncommon('Необычный'),
  rare('Редкий'),
  epic('Эпический'),
  legendary('Легендарный');

  const Rarity(this.label);
  final String label;
}

/// Предмет мира (таблица `items`).
class Item {
  const Item({
    required this.id,
    required this.slug,
    required this.title,
    required this.kind,
    required this.rarity,
    required this.level,
    required this.damage,
    required this.defense,
    required this.price,
  });

  final String id;
  final String slug;
  final String title;
  final ItemKind kind;
  final Rarity rarity;
  final int level;
  final int? damage;
  final int? defense;
  final int price;

  factory Item.fromRow(Map<String, dynamic> row) => Item(
    id: row['id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String,
    kind: ItemKind.values.byName(row['kind'] as String),
    rarity: Rarity.values.byName(row['rarity'] as String),
    level: row['level'] as int,
    damage: row['damage'] as int?,
    defense: row['defense'] as int?,
    price: row['price'] as int,
  );

  /// «Квестовый · Обычный · ур. 2 · 0 зол.» — строка под названием в списке.
  String get summary {
    final stat = switch (kind) {
      ItemKind.weapon => ' · урон $damage',
      ItemKind.armor => ' · защита $defense',
      _ => '',
    };
    return '${kind.label} · ${rarity.label} · ур. $level$stat · $price зол.';
  }
}

/// Черновик предмета из формы. slug назначает репозиторий при создании.
class NewItem {
  const NewItem({
    required this.title,
    required this.kind,
    required this.rarity,
    required this.level,
    this.damage,
    this.defense,
    required this.price,
  });

  final String title;
  final ItemKind kind;
  final Rarity rarity;
  final int level;
  final int? damage;
  final int? defense;
  final int price;

  Map<String, dynamic> toRow(String worldId, String slug) => {
    'project_id': worldId,
    'slug': slug,
    'title': title,
    'kind': kind.name,
    'rarity': rarity.name,
    'level': level,
    'damage': kind == ItemKind.weapon ? damage : null,
    'defense': kind == ItemKind.armor ? defense : null,
    'price': price,
  };
}
