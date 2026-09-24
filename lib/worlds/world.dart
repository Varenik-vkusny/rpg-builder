/// Мир автора (таблица `projects`).
class World {
  const World({
    required this.id,
    required this.title,
    required this.setting,
    required this.tone,
    required this.levelMin,
    required this.levelMax,
  });

  final String id;
  final String title;
  final String setting;
  final String tone;
  final int levelMin;
  final int levelMax;

  factory World.fromRow(Map<String, dynamic> row) => World(
        id: row['id'] as String,
        title: row['title'] as String,
        setting: row['setting'] as String,
        tone: row['tone'] as String,
        levelMin: row['level_min'] as int,
        levelMax: row['level_max'] as int,
      );
}

/// Черновик нового мира — то, что автор заполняет в форме.
class NewWorld {
  const NewWorld({
    required this.title,
    required this.setting,
    required this.tone,
    required this.levelMin,
    required this.levelMax,
  });

  final String title;
  final String setting;
  final String tone;
  final int levelMin;
  final int levelMax;

  Map<String, dynamic> toRow() => {
        'title': title,
        'setting': setting,
        'tone': tone,
        'level_min': levelMin,
        'level_max': levelMax,
      };
}
