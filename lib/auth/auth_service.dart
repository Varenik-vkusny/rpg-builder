import 'package:supabase/supabase.dart';

/// Вход и регистрация автора.
abstract class AuthService {
  Stream<bool> get signedInChanges;
  bool get isSignedIn;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._auth);

  final GoTrueClient _auth;

  @override
  Stream<bool> get signedInChanges =>
      _auth.onAuthStateChange.map((s) => s.session != null);

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  Future<void> signIn(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  @override
  Future<void> signUp(String email, String password) async {
    final res = await _auth.signUp(email: email, password: password);
    if (res.session == null) {
      throw const AuthException(
        'Регистрация прошла, но вход не выполнен: база требует подтверждения почты.',
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
