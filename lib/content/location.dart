/// Локация мира (таблица `locations`).
class Location {
  const Location({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.levelMin,
    required this.levelMax,
    this.parentId,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final int levelMin;
  final int levelMax;

  /// Место, внутри которого лежит это (5а); null — верхний уровень.
  final String? parentId;

  factory Location.fromRow(Map<String, dynamic> row) => Location(
    id: row['id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String,
    description: row['description'] as String,
    levelMin: row['level_min'] as int,
    levelMax: row['level_max'] as int,
    parentId: row['parent_id'] as String?,
  );
}

/// Черновик локации из формы. slug назначает репозиторий при создании.
class NewLocation {
  const NewLocation({
    required this.title,
    required this.description,
    required this.levelMin,
    required this.levelMax,
    this.parentId,
  });

  final String title;
  final String description;
  final int levelMin;
  final int levelMax;
  final String? parentId;

  Map<String, dynamic> toRow(String worldId, String slug) => {
    'project_id': worldId,
    'slug': slug,
    'title': title,
    'description': description,
    'level_min': levelMin,
    'level_max': levelMax,
    'parent_id': parentId,
  };
}
