/// Вид шага квеста. У каждого вида ровно одна цель:
/// поговорить — с персонажем, убить N — врагов, собрать N — предметов,
/// прийти — в локацию.
enum StepKind {
  talk('Поговорить', counted: false),
  kill('Убить', counted: true),
  collect('Собрать', counted: true),
  visit('Прийти', counted: false);

  const StepKind(this.label, {required this.counted});
  final String label;

  /// Нужно ли количество (убить N, собрать N).
  final bool counted;
}

/// Шаг квеста. [targetId] — персонаж, предмет или локация по виду шага.
class QuestStep {
  const QuestStep({required this.kind, required this.targetId, this.amount});

  final StepKind kind;
  final String targetId;
  final int? amount;

  factory QuestStep.fromRow(Map<String, dynamic> row) {
    final kind = StepKind.values.byName(row['kind'] as String);
    return QuestStep(
      kind: kind,
      targetId:
          (row['character_id'] ?? row['item_id'] ?? row['location_id'])
              as String,
      amount: row['amount'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    switch (kind) {
      StepKind.talk || StepKind.kill => 'character_id',
      StepKind.collect => 'item_id',
      StepKind.visit => 'location_id',
    }: targetId,
    if (kind.counted) 'amount': amount,
  };

  /// «Убить: Пепельный слизень × 4».
  String label(String targetTitle) =>
      '${kind.label}: $targetTitle${kind.counted ? ' × $amount' : ''}';
}

/// Квест мира (таблица `quests`) с шагами по порядку и наградами.
class Quest {
  const Quest({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.giverId,
    required this.steps,
    required this.rewardIds,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String giverId;
  final List<QuestStep> steps;
  final List<String> rewardIds;

  /// Строки под названием в списке мира: выдающий, шаги по порядку, награды.
  /// [titles] — названия всех персонажей, предметов и локаций мира по id.
  List<String> lines(Map<String, String> titles) {
    String t(String id) => titles[id] ?? '?';
    return [
      'Выдаёт: ${t(giverId)}',
      for (var i = 0; i < steps.length; i++)
        '${i + 1}. ${steps[i].label(t(steps[i].targetId))}',
      if (rewardIds.isNotEmpty) 'Награда: ${rewardIds.map(t).join(', ')}',
    ];
  }

  factory Quest.fromRow(Map<String, dynamic> row) {
    final steps = [
      for (final s in (row['quest_steps'] as List? ?? const []))
        s as Map<String, dynamic>,
    ]..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return Quest(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      giverId: row['giver_id'] as String,
      steps: steps.map(QuestStep.fromRow).toList(),
      rewardIds: [
        for (final r in (row['quest_rewards'] as List? ?? const []))
          (r as Map<String, dynamic>)['item_id'] as String,
      ],
    );
  }
}

/// Черновик квеста из формы. slug назначает репозиторий при создании.
class NewQuest {
  const NewQuest({
    required this.title,
    required this.description,
    required this.giverId,
    required this.steps,
    this.rewardIds = const [],
  });

  final String title;
  final String description;
  final String giverId;
  final List<QuestStep> steps;
  final List<String> rewardIds;

  Map<String, dynamic> toParams(String worldId, String slug) => {
    'p_project_id': worldId,
    'p_slug': slug,
    'p_title': title,
    'p_description': description,
    'p_giver_id': giverId,
    'p_steps': [for (final s in steps) s.toJson()],
    'p_rewards': rewardIds,
  };
}
