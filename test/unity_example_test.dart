// Прибор: пример для Unity (unity/RpgBuilderWorld.cs) не отстаёт от формата экспорта.
// Краснеет, если версия в C# другая, экспорт выдаёт поле, которого нет в классах C#,
// или C# читает поле, которого в экспорте нет либо у которого другой вид (число/строка/
// массив). Сам JsonUtility здесь не запускается — это делает только Unity.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/export/world_export.dart';

import 'assistant_fixtures.dart';
import 'event_step_test.dart' show minesWithEventStep;
import 'world_export_test.dart' show mines;

/// Классы C# → {имя класса: {поле: тип}}; тип без `[]`, массив помечен в [arrays].
Map<String, Map<String, String>> _csClasses(String src) {
  final out = <String, Map<String, String>>{};
  final cls = RegExp(r'public class (\w+)\s*\{([^{}]*)\}');
  for (final m in cls.allMatches(src)) {
    final fields = <String, String>{};
    // `public string a, b;` и `public Foo[] bar;`
    for (final f in RegExp(
      r'public\s+([\w]+(?:\[\])?)\s+([\w\s,]+);',
    ).allMatches(m[2]!)) {
      for (final name in f[2]!.split(',')) {
        fields[name.trim()] = f[1]!;
      }
    }
    out[m[1]!] = fields;
  }
  return out;
}

/// Идёт по JSON и классам C# вместе; возвращает, чего классам не хватает.
List<String> _missing(
  Object? json,
  String type,
  String path,
  Map<String, Map<String, String>> classes,
) {
  final out = <String>[];
  if (json is List) {
    for (final e in json) {
      out.addAll(_missing(e, type.replaceAll('[]', ''), path, classes));
    }
  } else if (json is Map) {
    final fields = classes[type];
    if (fields == null) return ['$path: нет класса $type'];
    for (final e in json.entries) {
      final f = fields[e.key];
      if (f == null) {
        out.add('$path.${e.key}: нет поля в классе $type');
      } else if (e.value is Map || e.value is List) {
        out.addAll(_missing(e.value, f, '$path.${e.key}', classes));
      }
    }
  }
  return out;
}

/// Обратная сторона (ревью 26.11): каждое поле, которое читает C#, есть в экспорте и того
/// же вида. Иначе поле, убранное из экспорта или сменившее тип, в Unity молча станет 0.
List<String> _wrong(
  Object? json,
  String type,
  String path,
  Map<String, Map<String, String>> classes,
) {
  final out = <String>[];
  if (json is List) {
    for (final e in json) {
      out.addAll(_wrong(e, type.replaceAll('[]', ''), path, classes));
    }
    return out;
  }
  if (json is! Map) return out;
  final fields = classes[type] ?? const {};
  for (final MapEntry(key: name, value: cs) in fields.entries) {
    final where = '$path.$name';
    if (!json.containsKey(name)) {
      out.add('$where: в экспорте нет поля, а $type его читает');
      continue;
    }
    final v = json[name];
    final ok = switch (cs) {
      'int' => v is int,
      'float' || 'double' => v is num,
      'string' => v is String,
      'bool' => v is bool,
      _ when cs.endsWith('[]') => v is List,
      _ => v is Map,
    };
    if (!ok) out.add('$where: в C# $cs, в экспорте ${v.runtimeType}');
    if (v is Map || v is List) out.addAll(_wrong(v, cs, where, classes));
  }
  return out;
}

void main() {
  final cs = File('unity/RpgBuilderWorld.cs').readAsStringSync();
  final classes = _csClasses(cs);

  test('Unity: версия формата в C# равна schemaVersion экспорта', () {
    final m = RegExp(r'ExpectedSchemaVersion\s*=\s*(\d+)').firstMatch(cs);
    expect(m, isNotNull, reason: 'в C# нет ExpectedSchemaVersion');
    expect(int.parse(m![1]!), schemaVersion);
  });

  test(
    'Unity: классы C# покрывают все ключи, которые выдаёт экспорт',
    () async {
      final (c, _) = await minesWithEventStep();
      final w = await c.snapshot(minesId);
      final json = jsonDecode(exportJson(mines, w));
      expect(_missing(json, 'WorldFile', r'$', classes), isEmpty);
      expect(_wrong(json, 'WorldFile', r'$', classes), isEmpty);
    },
  );

  test('Unity: образец мира — того же формата и читается классами C#', () {
    final sample = jsonDecode(
      File('unity/pepelnye_kopi.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(sample['schemaVersion'], schemaVersion);
    expect(_missing(sample, 'WorldFile', r'$', classes), isEmpty);
    final objects = [
      for (final k in ['locations', 'items', 'characters', 'events', 'quests'])
        ...(sample[k] as List),
    ];
    expect(objects, hasLength(40));
  });

  test('Unity: добыча врага (в образце пустая) есть в классах C#', () {
    // Ключи loot берём из world_export.dart: массив может быть пуст в любом мире.
    final src = File('lib/export/world_export.dart').readAsStringSync();
    expect(
      src,
      contains(RegExp(r"'item': ref\(l\.itemId\),\s*'chance': l\.chance")),
    );
    expect(classes['LootData']!.keys, containsAll(['item', 'chance']));
  });
}
