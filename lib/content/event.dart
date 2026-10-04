/// Враг события: кто и сколько. [id] — строка связи в базе; у новой строки его нет.
class EventEnemy {
  const EventEnemy({required this.characterId, required this.amount, this.id});

  final String? id;
  final String characterId;
  final int amount;

  factory EventEnemy.fromRow(Map<String, dynamic> row) => EventEnemy(
    id: row['id'] as String?,
    characterId: row['character_id'] as String,
    amount: row['amount'] as int,
  );

  Map<String, dynamic> toJson() => {
    'character_id': characterId,
    'amount': amount,
  };
}

/// Предмет события. [id] — строка связи в базе; у новой строки его нет.
class EventItem {
  const EventItem({required this.itemId, this.id});

  final String? id;
  final String itemId;

  factory EventItem.fromRow(Map<String, dynamic> row) =>
      EventItem(id: row['id'] as String?, itemId: row['item_id'] as String);
}

/// Событие мира (таблица `events`) — сцена в месте: враги с числом и предметы.
/// Условий запуска нет: когда сцена случается, решает игра (VISION §7).
class Event {
  const Event({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.locationId,
    this.enemies = const [],
    this.items = const [],
  });

  final String id;
  final String slug;
  final String title;
  final String description;

  /// Место сцены. В базе обязательно; null бывает только в копии мира —
  /// такое событие проверка мира отмечает ошибкой.
  final String? locationId;
  final List<EventEnemy> enemies;
  final List<EventItem> items;

  Iterable<String> get itemIds => items.map((i) => i.itemId);

  /// «Штольня №3 · Пепельный слизень × 3 · Ключ от лебёдки» — строка в списке мира.
  String summary(Map<String, String> titles) => [
    titles[locationId] ?? '?',
    for (final e in enemies) '${titles[e.characterId] ?? '?'} × ${e.amount}',
    for (final i in items) titles[i.itemId] ?? '?',
  ].join(' · ');

  factory Event.fromRow(Map<String, dynamic> row) => Event(
    id: row['id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String,
    description: row['description'] as String,
    locationId: row['location_id'] as String?,
    enemies: [
      for (final e in (row['event_enemies'] as List? ?? const []))
        EventEnemy.fromRow(e as Map<String, dynamic>),
    ],
    items: [
      for (final i in (row['event_items'] as List? ?? const []))
        EventItem.fromRow(i as Map<String, dynamic>),
    ],
  );
}

/// Черновик события из формы. slug назначает репозиторий при создании.
class NewEvent {
  const NewEvent({
    required this.title,
    required this.description,
    required this.locationId,
    this.enemies = const [],
    this.itemIds = const [],
  });

  final String title;
  final String description;
  final String locationId;
  final List<EventEnemy> enemies;
  final List<String> itemIds;

  Map<String, dynamic> toParams(String worldId, String slug) => {
    'p_project_id': worldId,
    'p_slug': slug,
    'p_title': title,
    'p_description': description,
    'p_location_id': locationId,
    'p_enemies': [for (final e in enemies) e.toJson()],
    'p_items': itemIds,
  };
}
