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
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/quest.dart';
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

  test('новый житель и событие встают в конец, старые не двигаются, и после повторного входа', () async {
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
    await npc('Бригадир');
    await event('Засада');

    await npc('Гоблин');
    await event('Крысы');
    final w = await repo.snapshot(world.id);

    expect([for (final c in w.characters) c.title], ['Бригадир', 'Гоблин']);
    expect([for (final e in w.events) e.title], ['Засада', 'Крысы']);
    // Жетоны места — по времени создания, вперемешку: событие «Засада» старше
    // «Гоблина» и стоит раньше него (не «сначала все жители, потом события»).
    expect(
      [for (final t in buildScene(w, null).places.single.tokens) t.title],
      ['Бригадир', 'Засада', 'Гоблин', 'Крысы'],
    );
  });

  test('новое место, предмет и квест — в конец холста и полки', () async {
    Future<Location> place(String title) => repo.createLocation(
      world.id,
      NewLocation(title: title, description: '', levelMin: 1, levelMax: 5),
    );
    Future<Item> item(String title) => repo.createItem(
      world.id,
      NewItem(
        title: title,
        kind: ItemKind.misc,
        rarity: Rarity.common,
        level: 1,
        price: 1,
      ),
    );
    final w0 = await repo.snapshot(world.id);
    final giver = w0.characters.first;
    Future<Quest> quest(String title) => repo.createQuest(
      world.id,
      NewQuest(
        title: title,
        description: '',
        giverId: giver.id,
        steps: [QuestStep(kind: StepKind.talk, targetId: giver.id)],
      ),
    );
    await place('Рынок');
    await item('Ключ');
    await quest('Обвал');
    await place('Забой');
    await item('Кирка');
    await quest('Завал');
    final w = await repo.snapshot(world.id);
    final scene = buildScene(w, null);

    expect(
      [for (final p in scene.places) p.place.title],
      ['Копи', 'Рынок', 'Забой'],
    );
    expect(
      [
        for (final t in scene.shelf)
          if (t.kind != TokenKind.npc && t.kind != TokenKind.enemy) t.title,
      ],
      ['Обвал', 'Завал', 'Ключ', 'Кирка'],
    );
  });
}
