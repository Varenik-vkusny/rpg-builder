// План изменений от ассистента — тот же формат, что у серверной функции
// (supabase/functions/assistant/plan.ts). Ссылки между объектами — по slug.

enum OpAction { create, update, delete }

enum OpType { location, item, character, quest, loot, questStep, questReward }

const _typeNames = {
  'location': OpType.location,
  'item': OpType.item,
  'character': OpType.character,
  'quest': OpType.quest,
  'loot': OpType.loot,
  'quest_step': OpType.questStep,
  'quest_reward': OpType.questReward,
};

/// Вид операции по имени из журнала или функции («quest_step»); неизвестное — null.
OpType? opTypeByName(String name) => _typeNames[name];

/// Одна операция плана. [fields] — только заданные поля (null в плане = «не задаю»).
class PlanOp {
  const PlanOp({
    required this.action,
    required this.type,
    this.slug,
    this.character,
    this.item,
    this.quest,
    this.position,
    this.fields = const {},
  });

  final OpAction action;
  final OpType type;
  final String? slug;
  final String? character;
  final String? item;
  final String? quest;
  final int? position;
  final Map<String, Object> fields;

  String get typeName =>
      _typeNames.entries.firstWhere((e) => e.value == type).key;

  factory PlanOp.fromJson(Map<String, dynamic> j) {
    final type = _typeNames[j['type']];
    if (type == null) {
      throw FormatException('неизвестный вид операции ${j['type']}');
    }
    return PlanOp(
      action: OpAction.values.byName(j['action'] as String),
      type: type,
      slug: j['slug'] as String?,
      character: j['character'] as String?,
      item: j['item'] as String?,
      quest: j['quest'] as String?,
      position: (j['position'] as num?)?.toInt(),
      fields: {
        for (final MapEntry(:key, :value)
            in ((j['fields'] as Map?) ?? const {}).entries)
          if (value != null) key as String: value as Object,
      },
    );
  }

  /// Обратно в формат функции: все поля, незаданные — null.
  Map<String, dynamic> toJson() => {
    'action': action.name,
    'type': typeName,
    'slug': slug,
    'character': character,
    'item': item,
    'quest': quest,
    'position': position,
    'fields': {for (final f in planFieldNames) f: fields[f]},
  };

  String? str(String f) => fields[f] as String?;
  int? integer(String f) => (fields[f] as num?)?.toInt();
  double? number(String f) => (fields[f] as num?)?.toDouble();
}

const planFieldNames = [
  'title',
  'description',
  'level_min',
  'level_max',
  'kind',
  'rarity',
  'level',
  'damage',
  'defense',
  'price',
  'role',
  'hp',
  'attack',
  'location',
  'giver',
  'step_kind',
  'target',
  'amount',
  'chance',
];

class Plan {
  const Plan({required this.summary, required this.ops});

  final String summary;
  final List<PlanOp> ops;

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    summary: j['summary'] as String? ?? '',
    ops: [
      for (final o in (j['ops'] as List? ?? const []))
        PlanOp.fromJson(o as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'ops': [for (final o in ops) o.toJson()],
  };
}
