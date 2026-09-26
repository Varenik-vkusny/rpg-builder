import 'package:flutter/material.dart';

import 'assistant/assistant_service.dart';
import 'auth/auth_screen.dart';
import 'auth/auth_service.dart';
import 'content/content_repo.dart';
import 'open5e/open5e_api.dart';
import 'worlds/worlds_repo.dart';
import 'worlds/worlds_screen.dart';

/// Корень: без входа — экран входа, после входа — список своих миров.
class RpgBuilderApp extends StatelessWidget {
  const RpgBuilderApp({
    super.key,
    required this.auth,
    required this.worlds,
    required this.content,
    required this.assistant,
    this.open5e = const HttpOpen5e(),
  });

  final AuthService auth;
  final WorldsRepo worlds;
  final ContentRepo content;
  final AssistantService assistant;
  final Open5eApi open5e;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RPG Builder',
      home: StreamBuilder<bool>(
        stream: auth.signedInChanges,
        initialData: auth.isSignedIn,
        builder: (context, snap) => snap.data == true
            // Новый ключ на каждый вход: после смены аккаунта список грузится заново.
            ? WorldsScreen(
                key: UniqueKey(),
                repo: worlds,
                content: content,
                assistant: assistant,
                open5e: open5e,
                onSignOut: auth.signOut,
              )
            : AuthScreen(auth: auth),
      ),
    );
  }
}
