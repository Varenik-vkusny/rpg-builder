import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'config.dart';
import 'worlds/worlds_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  final client = Supabase.instance.client;
  runApp(RpgBuilderApp(
    auth: SupabaseAuthService(client.auth),
    worlds: SupabaseWorldsRepo(client),
  ));
}
