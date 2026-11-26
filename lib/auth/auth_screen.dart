import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase/supabase.dart';

import '../ui/input_rules.dart';
import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(String, String) action) async {
    final email = _email.text.trim();
    final password = _password.text;
    final emailError = email.isEmpty
        ? 'Укажи почту'
        : looksLikeEmail(email)
        ? null
        : 'Почта выглядит неверно — нужен вид name@example.com';
    final passwordError = password.length < 6
        ? 'Пароль — не короче 6 символов'
        : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _error = null;
    });
    if (emailError != null || passwordError != null) return;
    setState(() => _busy = true);
    try {
      await action(email, password);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Не удалось: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Поле со своей ошибкой: красная линия снизу и под ним строка «❗ причина».
  Widget _field(
    String id,
    TextEditingController c,
    String label,
    IconData icon,
    String? error, {
    bool obscure = false,
  }) {
    final s = Theme.of(context).colorScheme;
    final line = error == null
        ? null
        : UnderlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: s.error, width: 2),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: Key(id),
          controller: c,
          obscureText: obscure,
          keyboardType: obscure ? null : TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            floatingLabelStyle: error == null
                ? null
                : TextStyle(color: s.error),
            enabledBorder: line,
            focusedBorder: line,
          ),
        ),
        if (error != null)
          Padding(
            key: Key('$id-error'),
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              spacing: 6,
              children: [
                Icon(Symbols.error_rounded, size: 18, color: s.error, fill: 1),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      color: s.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Icon(Symbols.auto_stories_rounded, size: 56, color: s.onSurface),
            const SizedBox(height: 16),
            Text(
              'RPG Builder',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Мир игры меняется одной фразой — и ничего не ломается',
              textAlign: TextAlign.center,
              style: TextStyle(color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            _field('email', _email, 'Почта', Symbols.mail_rounded, _emailError),
            _field(
              'password',
              _password,
              'Пароль',
              Symbols.lock_rounded,
              _passwordError,
              obscure: true,
            ),
            const SizedBox(height: 4),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: s.error)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              key: const Key('sign-in'),
              onPressed: _busy ? null : () => _run(widget.auth.signIn),
              child: const Text('Войти'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('sign-up'),
              onPressed: _busy ? null : () => _run(widget.auth.signUp),
              child: const Text('Зарегистрироваться'),
            ),
          ],
        ),
      ),
    );
  }
}
