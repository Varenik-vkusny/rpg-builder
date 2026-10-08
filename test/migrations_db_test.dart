// Прибор «папка миграций = база» (0в): имена файлов в supabase/migrations совпадают
// с именами миграций, накатанных на настоящую базу, в том же порядке.
// Версии не сравниваем: в базе это время накатки, в файле — номер среза.
// Пустой список с любой стороны — КРАСНО: прибор, не проведший измерения, кричит.
@Tags(['db'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

import 'db_helpers.dart';

/// `20261008000021_applied_migrations.sql` → `applied_migrations`.
String migrationName(String file) =>
    file.replaceFirst(RegExp(r'^\d{14}_'), '').replaceFirst(RegExp(r'\.sql$'), '');

void main() {
  test('папка миграций совпадает с накатанными на базу', () async {
    final files = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => RegExp(r'^\d{14}_.+\.sql$').hasMatch(n))
        .toList()
      ..sort();
    final inFolder = files.map(migrationName).toList();
    expect(inFolder, isNotEmpty, reason: 'в папке миграций не нашлось ни одной');

    final t = await testAuthor();
    final rows = await t.rpc('applied_migrations') as List<dynamic>;
    final inDb = rows.map((r) => r as String).toList();
    expect(inDb, isNotEmpty, reason: 'база не вернула ни одной миграции');

    final onlyFolder = inFolder.where((n) => !inDb.contains(n)).toList();
    final onlyDb = inDb.where((n) => !inFolder.contains(n)).toList();
    expect(
      [...onlyFolder, ...onlyDb],
      isEmpty,
      reason:
          'есть в папке, нет в базе: $onlyFolder; есть в базе, нет в папке: $onlyDb',
    );
    expect(inDb, inFolder, reason: 'имена те же, но порядок накатки другой');
  });

  test('без входа список миграций не отдаётся', () async {
    await expectLater(
      anonymous().rpc('applied_migrations'),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
      ),
    );
  });
}
