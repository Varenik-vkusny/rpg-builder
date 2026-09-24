// Путь автора по экранам без сети: регистрация → новый мир → он в списке.
// База подменена памятью; изоляцию между авторами проверяет worlds_rls_test.dart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/app.dart';
import 'package:rpg_builder/auth/auth_service.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';

class FakeAuth implements AuthService {
  final _changes = StreamController<bool>.broadcast();
  String? user;

  @override
  Stream<bool> get signedInChanges => _changes.stream;
  @override
  bool get isSignedIn => user != null;

  @override
  Future<void> signIn(String email, String password) async {
    user = email;
    _changes.add(true);
  }

  @override
  Future<void> signUp(String email, String password) => signIn(email, password);

  @override
  Future<void> signOut() async {
    user = null;
    _changes.add(false);
  }
}

/// Хранит миры по владельцу — как это делает RLS в базе.
class FakeWorlds implements WorldsRepo {
  FakeWorlds(this.auth);
  final FakeAuth auth;
  final _byOwner = <String, List<World>>{};

  @override
  Future<List<World>> listMine() async =>
      List.of(_byOwner[auth.user] ?? const []);

  @override
  Future<World> create(NewWorld w) async {
    final world = World(
      id: '${_byOwner.length}-${w.title}',
      title: w.title,
      setting: w.setting,
      tone: w.tone,
      levelMin: w.levelMin,
      levelMax: w.levelMax,
    );
    _byOwner.putIfAbsent(auth.user!, () => []).add(world);
    return world;
  }
}

Future<void> signUp(WidgetTester t, String email) async {
  await t.enterText(find.byKey(const Key('email')), email);
  await t.enterText(find.byKey(const Key('password')), 'secret123');
  await t.tap(find.byKey(const Key('sign-up')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('автор регистрируется, создаёт мир и видит его в списке',
      (t) async {
    final auth = FakeAuth();
    await t.pumpWidget(RpgBuilderApp(auth: auth, worlds: FakeWorlds(auth)));

    await signUp(t, 'a@test.dev');
    expect(find.text('Мои миры'), findsOneWidget);
    expect(find.text('Миров пока нет'), findsOneWidget);

    await t.tap(find.byKey(const Key('new-world')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('world-title')), 'Пепельные копи');
    await t.enterText(find.byKey(const Key('world-setting')), 'Шахтёрский посёлок');
    await t.enterText(find.byKey(const Key('world-tone')), 'мрачный');
    await t.tap(find.byKey(const Key('world-save')));
    await t.pumpAndSettle();

    expect(find.text('Пепельные копи'), findsOneWidget);
    expect(find.text('Уровни 1–10 · мрачный'), findsOneWidget);

    // Второй аккаунт мир не видит.
    await t.tap(find.byKey(const Key('sign-out')));
    await t.pumpAndSettle();
    await signUp(t, 'b@test.dev');
    expect(find.text('Пепельные копи'), findsNothing);
    expect(find.text('Миров пока нет'), findsOneWidget);
  });

  testWidgets('мир без названия не создаётся', (t) async {
    final auth = FakeAuth();
    final repo = FakeWorlds(auth);
    await t.pumpWidget(RpgBuilderApp(auth: auth, worlds: repo));
    await signUp(t, 'a@test.dev');

    await t.tap(find.byKey(const Key('new-world')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('world-save')));
    await t.pumpAndSettle();

    expect(find.text('Нужно название мира'), findsOneWidget);
    expect(await repo.listMine(), isEmpty);
  });
}
