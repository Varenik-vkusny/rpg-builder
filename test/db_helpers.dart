// Тестовые авторы в НАСТОЯЩЕЙ базе Supabase для приборов изоляции (RLS).
// Нужны переменные окружения RPGB_TEST_EMAIL_A, RPGB_TEST_EMAIL_B, RPGB_TEST_PASSWORD
// (scripts/check.sh берёт их из .env.test). Нет переменных — тест КРАСНЫЙ, а не пропущен.
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

/// Два тестовых автора: A и B.
Future<(SupabaseClient, SupabaseClient)> twoAuthors() async {
  final password = env('RPGB_TEST_PASSWORD');
  return (
    await author(env('RPGB_TEST_EMAIL_A'), password),
    await author(env('RPGB_TEST_EMAIL_B'), password),
  );
}

/// Клиент без входа.
SupabaseClient anonymous() =>
    SupabaseClient(supabaseUrl, supabasePublishableKey);
