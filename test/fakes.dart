// Подменённая база в памяти для тестов экранов: авторы, миры, содержимое.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/app.dart';
import 'package:rpg_builder/auth/auth_service.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/slug.dart';
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

/// Содержимое по мирам. Миры у авторов разные, так что изоляция — через FakeWorlds.
class FakeContent implements ContentRepo {
  final _locations = <String, List<Location>>{};

  @override
  Future<List<Location>> locations(String worldId) async =>
      List.of(_locations[worldId] ?? const []);

  @override
  Future<Location> createLocation(String worldId, NewLocation l) async {
    final list = _locations.putIfAbsent(worldId, () => []);
    final loc = Location(
      id: 'loc-${list.length}',
      slug: uniqueSlug(l.title, list.map((x) => x.slug)),
      title: l.title,
      description: l.description,
      levelMin: l.levelMin,
      levelMax: l.levelMax,
    );
    list.add(loc);
    return loc;
  }

  final _items = <String, List<Item>>{};

  @override
  Future<List<Item>> items(String worldId) async =>
      List.of(_items[worldId] ?? const []);

  @override
  Future<Item> createItem(String worldId, NewItem i) async {
    final list = _items.putIfAbsent(worldId, () => []);
    final row = i.toRow(worldId, uniqueSlug(i.title, list.map((x) => x.slug)));
    final item = Item.fromRow({...row, 'id': 'item-${list.length}'});
    list.add(item);
    return item;
  }

  final _characters = <String, List<Character>>{};

  @override
  Future<List<Character>> characters(String worldId) async =>
      List.of(_characters[worldId] ?? const []);

  @override
  Future<Character> createCharacter(String worldId, NewCharacter c) async {
    final list = _characters.putIfAbsent(worldId, () => []);
    final p = c.toParams(worldId, uniqueSlug(c.title, list.map((x) => x.slug)));
    final character = Character.fromRow({
      'id': 'char-${list.length}',
      'slug': p['p_slug'],
      'title': p['p_title'],
      'description': p['p_description'],
      'role': p['p_role'],
      'location_id': p['p_location_id'],
      'loot': p['p_loot'],
    });
    list.add(character);
    return character;
  }
}

/// Приложение на подменённой базе.
/// [wrap] — ключ рамки для снимков экрана (demo/snapshots_test.dart).
Future<FakeAuth> pumpApp(
  WidgetTester t, {
  FakeContent? content,
  GlobalKey? wrap,
}) async {
  final auth = FakeAuth();
  final app = RpgBuilderApp(
    auth: auth,
    worlds: FakeWorlds(auth),
    content: content ?? FakeContent(),
  );
  await t.pumpWidget(
    wrap == null ? app : RepaintBoundary(key: wrap, child: app),
  );
  return auth;
}

/// Создаёт мир через экран «Новый мир» (уровни по умолчанию 1–10).
Future<void> createWorld(WidgetTester t, String title) async {
  await t.tap(find.byKey(const Key('new-world')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('world-title')), title);
  await t.tap(find.byKey(const Key('world-save')));
  await t.pumpAndSettle();
}

Future<void> signUp(WidgetTester t, String email) async {
  await t.enterText(find.byKey(const Key('email')), email);
  await t.enterText(find.byKey(const Key('password')), 'secret123');
  await t.tap(find.byKey(const Key('sign-up')));
  await t.pumpAndSettle();
}
