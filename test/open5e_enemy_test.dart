// Прибор «враг из справочника» (5д, решение владельца 19.10): опасность → уровень,
// здоровье, средний урон первой атаки → атака; значок по имени, иначе по типу; карточка
// оригинала при враге и в экспорте; импорт — в историю, откат убирает врага.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/export/json_utility.dart';
import 'package:rpg_builder/export/world_export.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';
import 'package:rpg_builder/open5e/open5e_enemy.dart';

import 'apply_flow_test.dart' show tapButton;
import 'assistant_fixtures.dart';
import 'open5e_test.dart' show FakeOpen5e, openLibrary;
import 'world_export_test.dart' show mines;

/// Настоящие ответы api.open5e.com/v2/creatures/ (19.10.2026).
Open5eCreature creature(String file) => Open5eCreature.fromJson(
  jsonDecode(File('test/fixtures/open5e_$file.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  test('Скелет: ур. 1 из опасности 1/4, здоровье 13, атака 4 (1d6), значок по имени', () {
    final c = creature('skeleton');
    expect(c.type, 'undead');
    expect(levelOfChallenge(c.challenge), 1);
    expect(c.hp, 13);
    // Первая атака по статблоку — короткий меч 1d6 (лук идёт вторым).
    expect(c.firstAttack, (1, 6, 0));
    expect(attackOf(c), 4);
    expect(glyphOf(c), 'skeleton');
  });

  test(
    'Охряная слизь: имени в словаре нет — значок по типу «слизь»; 2d6 → 7',
    () {
      final c = creature('ochre_jelly');
      expect(levelOfChallenge(c.challenge), 2);
      expect(attackOf(c), 7);
      expect(glyphOf(c), 'slime');
      expect(levelOfChallenge(10.4), 10);
    },
  );

  testWidgets(
    'Враги → skeleton → карточка → Импортировать: враг с оригиналом, откат убирает',
    (t) async {
      final api = FakeOpen5e(const [], creatures: [creature('skeleton')]);
      final content = await openLibrary(t, api);
      await t.tap(find.text('Враги'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('open5e-query')), 'skeleton');
      await tapButton(t, 'open5e-search');
      expect(api.queries.last, 'skeleton');
      await tapButton(t, 'open5e-srd_skeleton');
      final preview = find.byKey(const Key('open5e-enemy-preview'));
      for (final s in ['Skeleton', '1', '13', '4', 'скелет']) {
        expect(
          find.descendant(of: preview, matching: find.text(s)),
          findsWidgets,
          reason: s,
        );
      }
      final sets = content.journal.length;
      await tapButton(t, 'open5e-import');
      final w = await content.snapshotOf(minesId);
      final e = w.characters.singleWhere((c) => c.slug == 'skeleton');
      expect(e.role, Role.enemy);
      expect((e.level, e.hp, e.attack, e.icon), (1, 13, 4, 'skeleton'));
      expect(e.origin!.ref, 'srd_skeleton');
      expect(e.origin!.card['armor_class'], 13);
      expect(content.journal.length, sets + 1);

      // Экспорт: источник и карточка строкой — JsonUtility читает, игра разберёт.
      final json = exportWorld(mines, await content.snapshotOf(minesId));
      final out = (json['characters'] as List).cast<Map>().singleWhere(
        (c) => c['slug'] == 'skeleton',
      );
      expect(out['source'], 'Open5e');
      expect(out['icon'], 'skeleton');
      expect(
        (jsonDecode(out['sourceCard'] as String) as Map)['hit_points'],
        13,
      );
      expect(jsonUtilityProblems(jsonDecode(jsonEncode(json))), isEmpty);

      await content.revertChangeSet(
        minesId,
        (await content.history(minesId)).first.id,
      );
      final back = await content.snapshotOf(minesId);
      expect(back.characters.where((c) => c.slug == 'skeleton'), isEmpty);
    },
  );
}
