// Подменные вход и миры (вынесено из fakes_db.dart 22.11 — файл перевалил за 400 строк).
import 'dart:async';

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

  @override
  Future<World> update(String id, NewWorld w) async {
    final mine = _byOwner[auth.user] ?? [];
    final i = mine.indexWhere((x) => x.id == id);
    if (i < 0) throw StateError('нет такого мира');
    return mine[i] = World(
      id: id,
      title: w.title,
      setting: w.setting,
      tone: w.tone,
      levelMin: w.levelMin,
      levelMax: w.levelMax,
    );
  }

  @override
  Future<void> delete(String id) async {
    final before = _byOwner[auth.user] ?? [];
    if (!before.any((x) => x.id == id)) throw StateError('нет такого мира');
    before.removeWhere((x) => x.id == id);
  }
}

/// Содержимое по мирам. Миры у авторов разные, так что изоляция — через FakeWorlds.
