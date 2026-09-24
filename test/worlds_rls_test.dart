// Изоляция миров в НАСТОЯЩЕЙ базе Supabase (RLS): два тестовых автора.
// Нужны переменные окружения RPGB_TEST_EMAIL_A, RPGB_TEST_EMAIL_B, RPGB_TEST_PASSWORD
// (scripts/check.sh берёт их из .env.test). Нет переменных — тест КРАСНЫЙ, а не пропущен.
@Tags(['db'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/config.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

String env(String name) {
  final v = Platform.environment[name];
  if (v == null || v.isEmpty) fail('Не задана переменная $name (см. .env.test)');
  return v;
}

/// Входит тестовым автором; если его ещё нет — регистрирует.
Future<SupabaseClient> author(String email, String password) async {
  final c = SupabaseClient(supabaseUrl, supabasePublishableKey,
      authOptions: const AuthClientOptions(
          autoRefreshToken: false, authFlowType: AuthFlowType.implicit));
  try {
    await c.auth.signInWithPassword(email: email, password: password);
  } on AuthException {
    final res = await c.auth.signUp(email: email, password: password);
    if (res.session == null) {
      fail('Регистрация без входа: в Supabase включено подтверждение почты');
    }
  }
  return c;
}

void main() {
  late SupabaseClient a;
  late SupabaseClient b;
  final title = 'Пепельные копи ${DateTime.now().microsecondsSinceEpoch}';
  String? createdId;

  setUpAll(() async {
    final password = env('RPGB_TEST_PASSWORD');
    a = await author(env('RPGB_TEST_EMAIL_A'), password);
    b = await author(env('RPGB_TEST_EMAIL_B'), password);
  });

  tearDownAll(() async {
    if (createdId != null) {
      await a.from('projects').delete().eq('id', createdId!);
    }
  });

  test('автор создаёт мир и видит его в своём списке', () async {
    final world = await SupabaseWorldsRepo(a).create(NewWorld(
        title: title, setting: 'Шахты', tone: 'мрачный', levelMin: 1, levelMax: 5));
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
        .update({'title': 'взломано'}).eq('id', createdId!).select();
    expect(updated, isEmpty);
    final deleted =
        await b.from('projects').delete().eq('id', createdId!).select();
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
    final anon = SupabaseClient(supabaseUrl, supabasePublishableKey);
    final rows = await anon.from('projects').select();
    expect(rows, isEmpty);
  });
}
