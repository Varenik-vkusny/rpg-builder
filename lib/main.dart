import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'assistant/assistant_service.dart';
import 'auth/auth_service.dart';
import 'config.dart';
import 'content/content_repo.dart';
import 'worlds/worlds_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    // Собрано без .env — подключаться некуда. Экран для того, кто собирает, не для автора.
    runApp(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xFF14110F),
          child: Center(
            child: Text(
              'Сервер не задан.\nСоберите с --dart-define-from-file=.env (README.md)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFEDE6DA), fontSize: 16),
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  final client = Supabase.instance.client;
  runApp(
    RpgBuilderApp(
      auth: SupabaseAuthService(client.auth),
      worlds: SupabaseWorldsRepo(client),
      content: SupabaseContentRepo(client),
      assistant: SupabaseAssistantService(client),
    ),
  );
}
