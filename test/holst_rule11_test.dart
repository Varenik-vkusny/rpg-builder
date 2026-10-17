// Прибор правила 11 (VISION §8): любая правка мира с холста идёт одной дорогой —
// проверка на копии, история, откат (lib/map/gesture_path.dart). Исключение одно —
// положение блока. Здесь две половины: (1) в коде холста нет записи в мир мимо дороги;
// (2) сама дорога: ошибка — ничего не записано, применённое — в истории и откатывается.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/map/gesture_create.dart';
import 'package:rpg_builder/map/gesture_path.dart';

import 'holst_fixture.dart';

/// Записи в мир: методы репозитория (со скобками или без — передача метода тоже запись)
/// и прямой путь в базу мимо репозитория (Supabase, rpc, from(...)).
final write = RegExp(
  r'\.(create[A-Z]\w*|applyChangeSet|rejectChangeSet|applyManualEdit|'
  r'revertChangeSet|moveLocation)\b|'
  r'\b(saveManualEdit|deleteManually)\b|'
  r'\.(rpc|from|insert|upsert|update|delete)\(|'
  r'(package:supabase)',
);

/// Где запись разрешена и сколько раз: дорога жеста — одна запись и один откат;
/// старая карта — положение блока (исключение правила 11).
const allowed = {
  'lib/map/gesture_path.dart': {'applyManualEdit': 1, 'revertChangeSet': 1},
  'lib/map/map_screen.dart': {'moveLocation': 1},
};

/// Код без комментариев — строчных и блочных.
String code(String src) => src
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

/// Нарушения в файлах [files]: путь, имя записи, сколько раз и сколько можно.
List<String> violations(Iterable<File> files) => [
  for (final f in files)
    for (final e in _count(code(f.readAsStringSync())).entries)
      if (e.value > (allowed[f.path.replaceAll(r'\', '/')]?[e.key] ?? 0))
        '${f.path}: ${e.key} ×${e.value}',
];

Map<String, int> _count(String src) {
  final out = <String, int>{};
  for (final m in write.allMatches(src)) {
    final name = m.group(1) ?? m.group(2) ?? m.group(3) ?? m.group(4)!;
    out[name] = (out[name] ?? 0) + 1;
  }
  return out;
}

void main() {
  test('в коде холста нет записи в мир мимо дороги жеста', () {
    final files = [
      for (final f in Directory('lib/map').listSync())
        if (f is File && f.path.endsWith('.dart')) f,
    ];
    // Прибор, которому нечего читать, — не прибор.
    expect(files.where((f) => f.path.contains('holst_')), isNotEmpty);
    final bad = violations(files);
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('прибор видит обходы: прямую базу, метод без скобок, вторую запись', () {
    final dir = Directory.systemTemp.createTempSync('rule11');
    addTearDown(() => dir.deleteSync(recursive: true));
    File put(String name, String src) =>
        File('${dir.path}/$name')..writeAsStringSync(src);
    for (final src in [
      "import 'package:supabase/supabase.dart';",
      'client.from("characters").insert(row);',
      'await db.rpc("apply_manual_edit");',
      'final f = repo.applyManualEdit;',
      'repo.createCharacter(w, c);',
    ]) {
      expect(violations([put('x.dart', src)]), isNotEmpty, reason: src);
    }
    // Комментарий — не запись.
    expect(
      violations([
        put(
          'y.dart',
          '// repo.createCharacter(w, c);\n/* repo.moveLocation */',
        ),
      ]),
      isEmpty,
    );
  });

  test('дорога: жест с ошибкой не записан и не попал в историю', () async {
    final c = await ashMines();
    final w = await c.snapshotOf(holstWorld.id);
    final before = c.journal.length;
    // Событие без места — ошибка проверки мира.
    final edit = ManualEdit(
      title: 'Холст: проба',
      slug: 'proba',
      ops: [
        rowOp('create', 'event', 'proba', {'project_id': holstWorld.id}),
      ],
      applyTo: (s) => WorldSnapshot(
        locations: s.locations,
        items: s.items,
        characters: s.characters,
        quests: s.quests,
        events: [
          ...s.events,
          const Event(
            id: 'x',
            slug: 'proba',
            title: 'Проба',
            description: '',
            locationId: null,
          ),
        ],
      ),
    );
    final r = await applyGesture(c, holstWorld.id, w, edit);
    expect(r.tone, GestureTone.error);
    expect(r.reason, contains('нет места'));
    expect(c.journal.length, before);
    expect((await c.snapshotOf(holstWorld.id)).events.length, w.events.length);
  });

  test('дорога: созданное жестом — в истории и откатывается', () async {
    final c = await ashMines();
    final w = await c.snapshotOf(holstWorld.id);
    final shaft = w.locations.firstWhere((l) => l.slug == 'shtolnya_3');
    final made = createByGesture(
      holstWorld.id,
      w,
      NewKind.enemy,
      placeId: shaft.id,
    );
    final r = await applyGesture(c, holstWorld.id, w, made.edit);
    expect(r.applied, isTrue);
    final history = await c.history(holstWorld.id);
    expect(history.first.id, r.setId);
    expect(history.first.request, 'Холст: создано «Новый враг»');
    final now = await c.snapshotOf(holstWorld.id);
    expect(
      now.characters.where((x) => x.id == made.id).single.locationId,
      shaft.id,
    );
    expect(await undoGesture(c, holstWorld.id, r.setId!), isNull);
    final back = await c.snapshotOf(holstWorld.id);
    expect(back.characters.where((x) => x.id == made.id), isEmpty);
  });
}
