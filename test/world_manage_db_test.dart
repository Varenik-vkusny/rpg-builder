// Переименование и удаление мира в НАСТОЯЩЕЙ базе: свой — можно (удаление уносит
// объекты каскадом), чужой — нельзя. Авторы — db_helpers.dart.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/manual_create.dart';
import 'package:rpg_builder/content/manual_save.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'db_helpers.dart';

NewWorld draft(String title) => NewWorld(
  title: title,
  setting: 'Шахты',
  tone: 'мрачный',
  levelMin: 2,
  levelMax: 7,
);

void main() {
  late SupabaseClient a;
  late SupabaseClient b;
  final created = <String>[];
  final stamp = DateTime.now().microsecondsSinceEpoch;

  setUpAll(() async {
    (a, b) = await twoAuthors();
  });

  tearDownAll(() async {
    for (final id in created) {
      await a.from('projects').delete().eq('id', id);
    }
  });

  Future<World> make(String title) async {
    final w = await SupabaseWorldsRepo(a).create(draft(title));
    created.add(w.id);
    return w;
  }

  test(
    'автор переименовывает свой мир: в базе новое имя, остальное цело',
    () async {
      final w = await make('Старое $stamp');
      final back = await SupabaseWorldsRepo(a)
          .update(w.id, draft('Новое $stamp'));
      expect(back.title, 'Новое $stamp');
      final row = await a.from('projects').select().eq('id', w.id).single();
      expect(row['title'], 'Новое $stamp');
      expect(row['level_min'], 2);
      expect(row['level_max'], 7);
    },
  );

  test('удаление мира уносит его объекты и историю', () async {
    final w = await make('Удаляемый $stamp');
    // Через форму: объект и набор «Создано вручную» в истории (правило 11).
    final error = await createManually(
      SupabaseContentRepo(a),
      w.id,
      (s) => createLocationEdit(
        w.id,
        s,
        const NewLocation(
          title: 'Рынок',
          description: '',
          levelMin: 2,
          levelMax: 7,
        ),
      ),
    );
    expect(error, isNull);
    Future<List<dynamic>> rows(String table) =>
        a.from(table).select().eq('project_id', w.id);
    expect(await rows('locations'), hasLength(1));
    expect(await rows('change_sets'), hasLength(1));
    await SupabaseWorldsRepo(a).delete(w.id);
    expect(await a.from('projects').select().eq('id', w.id), isEmpty);
    expect(await rows('locations'), isEmpty);
    // Вопрос обещает «и вся его история» — истории тоже нет.
    expect(await rows('change_sets'), isEmpty);
  });

  test('чужой мир нельзя ни переименовать, ни удалить', () async {
    final w = await make('Чужой $stamp');
    await expectLater(
      SupabaseWorldsRepo(b).update(w.id, draft('Взломан $stamp')),
      throwsA(anything),
    );
    await expectLater(SupabaseWorldsRepo(b).delete(w.id), throwsA(anything));
    final row = await a.from('projects').select().eq('id', w.id).single();
    expect(row['title'], 'Чужой $stamp');
  });
}
