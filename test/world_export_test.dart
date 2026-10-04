// Экспорт мира (4.5): JSON под JsonUtility Unity → «Поделиться»; перед экспортом — проверка мира.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/export/json_utility.dart';
import 'package:rpg_builder/export/world_export.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'event_step_test.dart' show minesWithEventStep;
import 'fakes.dart';

/// «Поделиться» без телефона: запоминает, что отдали.
/// Одна на весь файл: SharePlus.instance запоминает платформу при первом обращении.
class FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  static final instance = FakeShare();

  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

const mines = World(
  id: minesId,
  title: 'Пепельные копи',
  setting: 'шахты',
  tone: 'мрачный',
  levelMin: 1,
  levelMax: 10,
);

Future<FakeShare> openMinesWith(WidgetTester t, FakeContent content) async {
  t.view.physicalSize = const Size(800, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final share = FakeShare.instance..shared.clear();
  await pumpApp(t, content: content, assistant: FakeAssistant());
  await signUp(t, 'a@test.dev');
  await createWorld(t, 'Пепельные копи');
  await openWorld(t, 'Пепельные копи');
  return share;
}

Future<Map<String, dynamic>> sharedJson(FakeShare s) async =>
    jsonDecode(await s.shared.single.files!.single.readAsString())
        as Map<String, dynamic>;

void main() {
  SharePlatform.instance = FakeShare.instance;

  test(
    'экспорт: корень-объект, schemaVersion, ссылки через slug, без null',
    () async {
      final c = await minesContent();
      final json = exportWorld(mines, await c.snapshot(minesId));
      expect(json['schemaVersion'], 1);
      expect((json['world'] as Map)['slug'], 'pepelnye_kopi');
      final slime = (json['characters'] as List).cast<Map>().firstWhere(
        (x) => x['slug'] == 'slizen',
      );
      expect(slime['location'], 'shtolnya_3');
      expect((slime['loot'] as List).single, {
        'item': 'klyuch',
        'chance': 35.0,
      });
      final quest = (json['quests'] as List).single as Map;
      expect(quest['giver'], 'brigadir');
      expect(
        [for (final s in quest['steps'] as List) (s as Map)['target']],
        ['brigadir', 'slizen', 'klyuch'],
      );
      expect(quest['rewards'], [
        {'item': 'kirka', 'amount': 1},
      ]);
      expect(
        jsonUtilityProblems(
          jsonDecode(exportJson(mines, await c.snapshot(minesId))),
        ),
        isEmpty,
      );
      expect(exportFileName(mines), 'pepelnye_kopi.json');
    },
  );

  test('экспорт: события — массивом, ссылки через slug, без словарей; шаг '
      'квеста ведёт на событие', () async {
    final (c, _) = await minesWithEventStep();
    // Второе событие — пустая сцена: у всех событий в файле один набор полей.
    final w0 = await c.snapshot(minesId);
    await c.createEvent(
      minesId,
      NewEvent(
        title: 'Тишина',
        description: '',
        locationId: w0.locations.firstWhere((l) => l.slug == 'rynok').id,
      ),
    );
    final w = await c.snapshot(minesId);
    final json = exportWorld(mines, w);
    expect(json['events'], [
      {
        'slug': 'zasada_u_lebedki',
        'name': 'Засада у лебёдки',
        'description': 'слизни падают с потолка',
        'location': 'shtolnya_3',
        'enemies': [
          {'enemy': 'slizen', 'amount': 3},
        ],
        'items': [
          {'item': 'klyuch', 'amount': 1},
        ],
      },
      {
        'slug': 'tishina',
        'name': 'Тишина',
        'description': '',
        'location': 'rynok',
        'enemies': <Object>[],
        'items': <Object>[],
      },
    ]);
    final step = ((json['quests'] as List).single as Map)['steps'] as List;
    expect(step.last, {'kind': 'event', 'target': 'zasada_u_lebedki', 'amount': 1});
    // Файл целиком читается JsonUtility: без null, словарей и вложенных массивов.
    expect(jsonUtilityProblems(jsonDecode(exportJson(mines, w))), isEmpty);
    // События есть и в мире без событий — пустым массивом, а не пропуском поля.
    final empty = exportWorld(mines, await (await minesContent()).snapshot(minesId));
    expect(empty['events'], isEmpty);
    expect(empty.keys, contains('events'));
  });

  test('экспорт: у места родитель по slug; место верхнего уровня — «»', () async {
    final c = await minesContent();
    final kopi = await c.createLocation(
      minesId,
      const NewLocation(
        title: 'Копи',
        description: '',
        levelMin: 1,
        levelMax: 6,
      ),
    );
    await c.createLocation(
      minesId,
      NewLocation(
        title: 'Колодец',
        description: '',
        levelMin: 2,
        levelMax: 3,
        parentId: kopi.id,
      ),
    );
    final json = exportWorld(mines, await c.snapshot(minesId));
    final parents = {
      for (final l in (json['locations'] as List).cast<Map>())
        l['slug']: l['parent'],
    };
    expect(parents['kolodets'], 'kopi');
    expect(parents['kopi'], '');
    // Только эти поля: положение блока на карте — раскладка автора, в игру не идёт.
    for (final l in (json['locations'] as List).cast<Map>()) {
      expect(l.keys.toSet(), {
        'slug',
        'name',
        'description',
        'levelMin',
        'levelMax',
        'parent',
      });
    }
    expect(jsonUtilityProblems(jsonDecode(jsonEncode(json))), isEmpty);
  });

  test('экспорт: прибор C#-совместимости краснеет на словаре, null и без schemaVersion', () {
    // Словарь «slug → предмет» — JsonUtility его не читает.
    expect(
      jsonUtilityProblems({
        'schemaVersion': 1,
        'items': {
          'kirka': {'slug': 'kirka', 'level': 3},
        },
      }),
      isNotEmpty,
    );
    // Объекты одного массива с разными полями — тоже словарь по сути.
    expect(
      jsonUtilityProblems({
        'schemaVersion': 1,
        'items': [
          {'slug': 'a', 'level': 1},
          {'slug': 'b', 'damage': 2},
        ],
      }),
      isNotEmpty,
    );
    expect(
      jsonUtilityProblems({
        'schemaVersion': 1,
        'items': [
          {'damage': null},
        ],
      }),
      isNotEmpty,
    );
    expect(jsonUtilityProblems({'items': []}), isNotEmpty);
    expect(jsonUtilityProblems([]), isNotEmpty);
    expect(jsonUtilityProblems({'schemaVersion': 1, 'items': []}), isEmpty);
  });

  testWidgets(
    'экспорт: мир без ошибок — сразу «Поделиться» файлом pepelnye_kopi.json',
    (t) async {
      final share = await openMinesWith(t, await minesContent());
      await tapButton(t, 'world-export');
      expect(find.byKey(const Key('export-errors')), findsNothing);
      expect(share.shared.single.fileNameOverrides, ['pepelnye_kopi.json']);
      final json = await sharedJson(share);
      expect(json['schemaVersion'], 1);
      expect((json['items'] as List).length, 2);
    },
  );

  testWidgets('экспорт: файл из «Поделиться» содержит событие мира', (t) async {
    final content = await minesContent();
    await addAmbush(content, minesId);
    final share = await openMinesWith(t, content);
    await tapButton(t, 'world-export');
    // Мир с событием — без ошибок проверки: окна ошибок нет, файл ушёл сразу.
    expect(find.byKey(const Key('export-errors')), findsNothing);
    final event = ((await sharedJson(share))['events'] as List).single as Map;
    expect(event['name'], 'Засада у лебёдки');
    expect(event['location'], 'shtolnya_3');
    expect(event['enemies'], [
      {'enemy': 'slizen', 'amount': 3},
    ]);
  });

  testWidgets(
    'экспорт: в мире ошибка — предупреждение; отмена не отправляет, «всё равно» отправляет',
    (t) async {
      final content = await minesContent();
      // Житель ссылается на несуществующую локацию — ошибка проверки мира.
      await content.createCharacter(
        minesId,
        const NewCharacter(
          title: 'Призрак',
          description: '',
          role: Role.npc,
          locationId: 'loc-нет',
        ),
      );
      final share = await openMinesWith(t, content);
      await tapButton(t, 'world-export');
      expect(find.byKey(const Key('export-errors')), findsOneWidget);
      expect(find.textContaining('Ошибок в мире: 1'), findsOneWidget);
      await tapButton(t, 'export-cancel');
      expect(share.shared, isEmpty);

      await tapButton(t, 'world-export');
      await tapButton(t, 'export-anyway');
      expect(share.shared, hasLength(1));
      final ghost = ((await sharedJson(share))['characters'] as List)
          .cast<Map>()
          .firstWhere((x) => x['slug'] == 'prizrak');
      expect(
        ghost['location'],
        '',
        reason: 'ссылка в никуда — пустая строка, не null',
      );
    },
  );
}
