// Порядок объектов места в НАСТОЯЩЕЙ базе (владелец 19.11 и 21.11): старые первыми,
// новое — в конец. Библиотека базы сортирует «новые первыми», если не попросить иначе,
// а подменённая база в тестах — «старые первыми»: тесты были зелёные, а на телефоне
// каждый новый враг вставал в первую клетку и сдвигал всех (найдено запуском 21.11).
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/map/holst_scene.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'db_helpers.dart';

void main() {
  late SupabaseClient a;
  late World world;
  late SupabaseContentRepo repo;

  setUpAll(() async {
    a = await testAuthor();
    repo = SupabaseContentRepo(a);
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Порядок ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
  });

  tearDownAll(() => a.from('projects').delete().eq('id', world.id));

  test('новый житель и событие встают в конец, старые не двигаются', () async {
    final place = await repo.createLocation(
      world.id,
      const NewLocation(
        title: 'Копи',
        description: '',
        levelMin: 1,
        levelMax: 5,
      ),
    );
    Future<Character> npc(String title) => repo.createCharacter(
      world.id,
      NewCharacter(
        title: title,
        description: '',
        role: Role.npc,
        locationId: place.id,
      ),
    );
    Future<Event> event(String title) => repo.createEvent(
      world.id,
      NewEvent(title: title, description: '', locationId: place.id),
    );
    final brigadir = await npc('Бригадир');
    final ambush = await event('Засада');

    Future<Map<String, int>> cellsNow() async {
      final w = await repo.snapshot(world.id);
      return buildScene(w, null).places.single.cellOf;
    }

    final before = await cellsNow();
    final goblin = await npc('Гоблин');
    final rat = await event('Крысы');
    final w = await repo.snapshot(world.id);

    expect([for (final c in w.characters) c.title], ['Бригадир', 'Гоблин']);
    expect([for (final e in w.events) e.title], ['Засада', 'Крысы']);
    final after = await cellsNow();
    expect(after[brigadir.id], before[brigadir.id]);
    expect(after[ambush.id], before[ambush.id]);
    expect(after.containsKey(goblin.id) && after.containsKey(rat.id), isTrue);
  });
}
