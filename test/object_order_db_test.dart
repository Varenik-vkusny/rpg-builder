// Порядок объектов места в НАСТОЯЩЕЙ базе (владелец 19.11 и 21.11): старые первыми,
// новое — в конец. Библиотека базы сортирует «новые первыми», если не попросить иначе,
// а подменённая база в тестах — «старые первыми»: тесты были зелёные, а на телефоне
// каждый новый враг вставал в первую клетку и сдвигал всех (найдено запуском 21.11).
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_apply.dart' show titleOrder;
import 'package:rpg_builder/check/world_check.dart';
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

  test(
    'одно «Применить»: созданные в один миг — по названию, при каждой загрузке',
    () async {
      final w0 = await repo.snapshot(world.id);
      final kopi = w0.locations.firstWhere((l) => l.title == 'Копи').slug;
      Map<String, dynamic> op(
        String type,
        String slug,
        Map<String, Object> f,
      ) => {'action': 'create', 'type': type, 'slug': slug, 'fields': f};
      // Порядок операций нарочно не по алфавиту: Вепрь, Акула, Бес.
      final plan = Plan.fromJson({
        'summary': 'стая',
        'ops': [
          for (final (slug, title) in [
            ('vepr', 'Вепрь'),
            ('akula', 'Акула'),
            ('bes', 'Бес'),
          ])
            op('character', slug, {
              'title': title,
              'role': 'enemy',
              'location': kopi,
            }),
          for (final (slug, title) in [
            ('yashik', 'Ящик'),
            ('verevka', 'Верёвка'),
            ('yozh', 'Ёж'),
            ('eda', 'Еда'),
            ('akula_zub', 'акула-зуб'),
            ('bes_rog', 'Бес рог'),
            ('rog_1', 'Рог'),
            ('rog_2', 'рог'),
          ])
            op('item', slug, {
              'title': title,
              'kind': 'misc',
              'rarity': 'common',
              'level': 1,
              'price': 1,
            }),
        ],
      });
      await repo.applyChangeSet(
        world.id,
        ChangeSetDraft(
          scope: Scope(ScopeType.location, kopi),
          request: 'стая',
          plan: plan,
          inputTokens: 0,
          outputTokens: 0,
          attempts: 1,
        ),
      );
      List<String> placeOrder(WorldSnapshot w) => [
        for (final t in buildScene(w, null).places.first.tokens) t.title,
      ];
      List<String> shelfItems(WorldSnapshot w) => [
        for (final t in buildScene(w, null).shelf)
          if (t.kind == TokenKind.item) t.title,
      ];
      for (var i = 0; i < 3; i++) {
        final w = await repo.snapshot(world.id);
        // Старые — по времени, новые из одного набора — по названию (у событий на боевом
        // сервере операций плана нет — ступень 2 отложена).
        expect(placeOrder(w), [
          'Бригадир',
          'Засада',
          'Гоблин',
          'Крысы',
          'Акула',
          'Бес',
          'Вепрь',
        ]);
        // Новые предметы — тем же правилом, что в приложении (titleOrder): база и копия
        // плана упорядочивают одинаково, в том числе регистр, «ё» и знаки.
        expect(shelfItems(w), [
          'Ключ',
          'Кирка',
          ...([
            'Ящик',
            'Верёвка',
            'Ёж',
            'Еда',
            'акула-зуб',
            'Бес рог',
            'Рог',
            'рог',
          ]..sort(titleOrder)),
        ]);
        expect(shelfItems(w).sublist(2), [
          'акула-зуб',
          'Бес рог',
          'Верёвка',
          'Еда',
          'Ёж',
          'рог',
          'Рог',
          'Ящик',
        ]);
      }
    },
  );
}
