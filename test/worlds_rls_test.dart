// Изоляция миров в НАСТОЯЩЕЙ базе Supabase (RLS): два тестовых автора.
// Авторы и переменные окружения — в db_helpers.dart.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'db_helpers.dart';

void main() {
  late SupabaseClient a;
  late SupabaseClient b;
  final title = 'Пепельные копи ${DateTime.now().microsecondsSinceEpoch}';
  String? createdId;

  setUpAll(() async {
    (a, b) = await twoAuthors();
  });

  tearDownAll(() async {
    if (createdId != null) {
      await a.from('projects').delete().eq('id', createdId!);
    }
  });

  test('автор создаёт мир и видит его в своём списке', () async {
    final world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: title,
        setting: 'Шахты',
        tone: 'мрачный',
        levelMin: 1,
        levelMax: 5,
      ),
    );
    createdId = world.id;
    final mine = await SupabaseWorldsRepo(a).listMine();
    expect(mine.map((w) => w.id), contains(world.id));
  });

  test('второй автор чужой мир не видит', () async {
    final theirs = await SupabaseWorldsRepo(b).listMine();
    expect(theirs.map((w) => w.title), isNot(contains(title)));
    final direct = await b.from('projects').select().eq('id', createdId!);
    expect(direct, isEmpty);
  });

  test('второй автор не может изменить или удалить чужой мир', () async {
    final updated = await b
        .from('projects')
        .update({'title': 'взломано'})
        .eq('id', createdId!)
        .select();
    expect(updated, isEmpty);
    final deleted = await b
        .from('projects')
        .delete()
        .eq('id', createdId!)
        .select();
    expect(deleted, isEmpty);
    final still = await a.from('projects').select('title').eq('id', createdId!);
    expect(still.single['title'], title);
  });

  test('второй автор не может создать мир от чужого имени', () async {
    final aId = a.auth.currentUser!.id;
    await expectLater(
      b.from('projects').insert({
        'owner_id': aId,
        'title': 'подкидыш',
        'level_min': 1,
        'level_max': 2,
      }),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('без входа миры не читаются', () async {
    final anon = anonymous();
    final rows = await anon.from('projects').select();
    expect(rows, isEmpty);
  });
}
