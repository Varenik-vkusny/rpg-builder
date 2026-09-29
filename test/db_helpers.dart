// Тестовые авторы в НАСТОЯЩЕЙ базе Supabase для приборов изоляции (RLS).
// Нужны переменные окружения RPGB_TEST_EMAIL_T, RPGB_TEST_EMAIL_B, RPGB_TEST_PASSWORD
// (scripts/check.sh берёт их из .env.test). Нет переменных — тест КРАСНЫЙ, а не пропущен.
// Автор А (RPGB_TEST_EMAIL_A) — для показа руками: тесты под ним не входят,
// check.sh это стережёт (scripts/author_a_worlds.sh).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/config.dart';
import 'package:supabase/supabase.dart';

String env(String name) {
  final v = Platform.environment[name];
  if (v == null || v.isEmpty) {
    fail('Не задана переменная $name (см. .env.test)');
  }
  return v;
}

/// Входит тестовым автором; если его ещё нет — регистрирует.
Future<SupabaseClient> author(String email, String password) async {
  final c = SupabaseClient(
    supabaseUrl,
    supabasePublishableKey,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
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

/// Тестовый автор Т: под ним пишут тесты с базой, живые прогоны и видео.
/// Мир, оставшийся от прерванного прогона (старше часа), убирается при входе —
/// свежие не трогаем: соседний файл тестов может работать с ними прямо сейчас.
Future<SupabaseClient> testAuthor() async {
  final t = await author(env('RPGB_TEST_EMAIL_T'), env('RPGB_TEST_PASSWORD'));
  final hourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));
  await t
      .from('projects')
      .delete()
      .lt('created_at', hourAgo.toIso8601String());
  return t;
}

/// Два тестовых автора: Т (пишет) и B (чужой, проверяет изоляцию).
Future<(SupabaseClient, SupabaseClient)> twoAuthors() async => (
  await testAuthor(),
  await author(env('RPGB_TEST_EMAIL_B'), env('RPGB_TEST_PASSWORD')),
);

/// Клиент без входа.
SupabaseClient anonymous() =>
    SupabaseClient(supabaseUrl, supabasePublishableKey);

/// Запрет смены slug (VISION.md, правило 8) проверяется самим триггером базы:
/// проба `slug_change_blocked` делает настоящий update и откатывает его.
/// Обычный update сюда не годится — его раньше триггера отсекает RLS.
Future<void> expectSlugLocked(
  SupabaseClient who,
  String table,
  String id,
  String slug,
) async {
  final blocked = await who.rpc(
    'slug_change_blocked',
    params: {'p_table': table, 'p_id': id},
  );
  expect(blocked, isTrue, reason: 'триггер $table не остановил смену slug');
  final row = await who.from(table).select('slug').eq('id', id).single();
  expect(row['slug'], slug, reason: 'проба не должна ничего менять');
}
