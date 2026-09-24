enum Role {
  npc('Житель'),
  merchant('Торговец'),
  enemy('Враг');

  const Role(this.label);
  final String label;
}

/// Строка добычи: враг роняет предмет с шансом 0 < шанс ≤ 100 (проценты).
class LootDrop {
  const LootDrop({required this.itemId, required this.chance});

  final String itemId;
  final double chance;

  static bool validChance(double chance) => chance > 0 && chance <= 100;

  /// 35.0 → «35%», 12.5 → «12.5%».
  String get chanceLabel =>
      '${chance == chance.roundToDouble() ? chance.round() : chance}%';

  factory LootDrop.fromRow(Map<String, dynamic> row) => LootDrop(
    itemId: row['item_id'] as String,
    chance: (row['chance'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'item_id': itemId, 'chance': chance};
}

/// Персонаж мира (таблица `characters`) вместе с добычей.
class Character {
  const Character({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.role,
    required this.locationId,
    required this.loot,
    this.level = 1,
    this.hp = 10,
    this.attack = 0,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final Role role;
  final String? locationId;
  final List<LootDrop> loot;
  final int level;
  final int hp;
  final int attack;

  /// «Враг · ур. 3 · здоровье 30 · атака 8 · Штольня №3 · роняет: Ключ от лебёдки 35%» — строка в списке мира.
  String summary(
    Map<String, String> locationTitles,
    Map<String, String> itemTitles,
  ) {
    final parts = [
      role.label,
      'ур. $level · здоровье $hp · атака $attack',
      if (locationId != null) locationTitles[locationId] ?? '?',
      if (loot.isNotEmpty)
        'роняет: ${loot.map((l) => '${itemTitles[l.itemId] ?? '?'} ${l.chanceLabel}').join(', ')}',
    ];
    return parts.join(' · ');
  }

  factory Character.fromRow(Map<String, dynamic> row) => Character(
    id: row['id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String,
    description: row['description'] as String,
    role: Role.values.byName(row['role'] as String),
    locationId: row['location_id'] as String?,
    level: row['level'] as int,
    hp: row['hp'] as int,
    attack: row['attack'] as int,
    loot: [
      for (final l in (row['loot'] as List? ?? const []))
        LootDrop.fromRow(l as Map<String, dynamic>),
    ],
  );
}

/// Черновик персонажа из формы. slug назначает репозиторий при создании.
/// Добыча бывает только у врага.
class NewCharacter {
  const NewCharacter({
    required this.title,
    required this.description,
    required this.role,
    required this.locationId,
    this.loot = const [],
    this.level = 1,
    this.hp = 10,
    this.attack = 0,
  });

  final String title;
  final String description;
  final Role role;
  final String? locationId;
  final List<LootDrop> loot;
  final int level;
  final int hp;
  final int attack;

  Map<String, dynamic> toParams(String worldId, String slug) => {
    'p_project_id': worldId,
    'p_slug': slug,
    'p_title': title,
    'p_description': description,
    'p_role': role.name,
    'p_location_id': locationId,
    'p_level': level,
    'p_hp': hp,
    'p_attack': attack,
    'p_loot': role == Role.enemy
        ? [for (final l in loot) l.toJson()]
        : const [],
  };
}
