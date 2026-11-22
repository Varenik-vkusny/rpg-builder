// Правило 11 в НАСТОЯЩЕЙ базе (найдено на телефоне 22.11): созданное ФОРМОЙ — место,
// предмет, персонаж с добычей, квест с шагами и наградой, событие с врагом и предметом —
// попадает в «Историю изменений» набором «Создано вручную» и откатывается целиком.
// Раньше форма писала в базу напрямую: 18 объектов из форм в истории не было.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/event.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/content/manual_create.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/content/manual_save.dart';
import 'package:rpg_builder/content/quest.dart';
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
        title: 'Формы ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
  });

  tearDownAll(() => a.from('projects').delete().eq('id', world.id));

  Future<void> create(ManualEdit Function(WorldSnapshot) build) async {
    final error = await createManually(repo, world.id, build);
    expect(error, isNull);
  }

  test('каждая форма создаёт через историю; откат убирает созданное', () async {
    final id = world.id;
    await create(
      (w) => createLocationEdit(
        id,
        w,
        const NewLocation(
          title: 'Копи',
          description: '',
          levelMin: 1,
          levelMax: 5,
        ),
      ),
    );
    var w = await repo.snapshot(id);
    final kopi = w.locations.single;
    await create(
      (w) => createLocationEdit(
        id,
        w,
        NewLocation(
          title: 'Штольня',
          description: '',
          levelMin: 1,
          levelMax: 5,
          parentId: kopi.id,
        ),
      ),
    );
    await create(
      (w) => createItemEdit(
        id,
        w,
        const NewItem(
          title: 'Кирка',
          kind: ItemKind.weapon,
          rarity: Rarity.common,
          level: 1,
          damage: 4,
          price: 15,
        ),
      ),
    );
    w = await repo.snapshot(id);
    expect(
      w.locations.firstWhere((l) => l.title == 'Штольня').parentId,
      kopi.id,
    );
    final pick = w.items.single;
    expect((pick.kind, pick.damage, pick.price), (ItemKind.weapon, 4, 15));
    await create(
      (w) => createItemEdit(
        id,
        w,
        const NewItem(
          title: 'Ключ',
          kind: ItemKind.quest,
          rarity: Rarity.common,
          level: 1,
          price: 0,
        ),
      ),
    );
    w = await repo.snapshot(id);
    final key = w.items.firstWhere((i) => i.title == 'Ключ');
    await create(
      (w) => createCharacterEdit(
        id,
        w,
        NewCharacter(
          title: 'Бригадир',
          description: '',
          role: Role.npc,
          locationId: kopi.id,
        ),
      ),
    );
    await create(
      (w) => createCharacterEdit(
        id,
        w,
        NewCharacter(
          title: 'Слизень',
          description: '',
          role: Role.enemy,
          locationId: kopi.id,
          level: 2,
          hp: 12,
          attack: 3,
          loot: [LootDrop(itemId: key.id, chance: 35)],
        ),
      ),
    );
    w = await repo.snapshot(id);
    final brigadir = w.characters.firstWhere((c) => c.title == 'Бригадир');
    final slime = w.characters.firstWhere((c) => c.title == 'Слизень');
    expect(slime.loot.single.chance, 35);
    expect((slime.level, slime.hp, slime.attack), (2, 12, 3));
    await create(
      (w) => createQuestEdit(
        id,
        w,
        NewQuest(
          title: 'Обвал',
          description: '',
          giverId: brigadir.id,
          steps: [
            QuestStep(kind: StepKind.talk, targetId: brigadir.id),
            QuestStep(kind: StepKind.kill, targetId: slime.id, amount: 4),
          ],
          rewardIds: [key.id],
        ),
      ),
    );
    await create(
      (w) => createEventEdit(
        id,
        w,
        NewEvent(
          title: 'Засада',
          description: '',
          locationId: kopi.id,
          enemies: [EventEnemy(characterId: slime.id, amount: 3)],
          itemIds: [key.id],
        ),
      ),
    );
    w = await repo.snapshot(id);
    expect(
      [for (final s in w.quests.single.steps) (s.kind, s.amount)],
      [(StepKind.talk, null), (StepKind.kill, 4)],
    );
    expect(w.quests.single.rewardIds, [key.id]);
    expect(w.events.single.enemies.single.amount, 3);
    expect(w.events.single.items.single.itemId, key.id);

    // Все шесть — в истории, от новых к старым.
    final history = await repo.history(id);
    expect(
      [for (final h in history) h.request],
      [
        'Создано вручную: Засада',
        'Создано вручную: Обвал',
        'Создано вручную: Слизень',
        'Создано вручную: Бригадир',
        'Создано вручную: Ключ',
        'Создано вручную: Кирка',
        'Создано вручную: Штольня',
        'Создано вручную: Копи',
      ],
    );

    // Откат с новых к старым — мир снова пуст.
    for (final h in history) {
      await repo.revertChangeSet(id, h.id);
    }
    w = await repo.snapshot(id);
    expect(
      [
        w.locations,
        w.items,
        w.characters,
        w.quests,
        w.events,
      ].every((l) => l.isEmpty),
      isTrue,
    );
  });
}
