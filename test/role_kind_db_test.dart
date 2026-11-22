// Смена роли персонажа и вида предмета формой правки в НАСТОЯЩЕЙ базе (владелец 22.11,
// заход 1 репетиции: кнопки были серыми). Роль и вид пишутся набором «Правка вручную»,
// откатываются; враг стал жителем — его добыча уходит тем же набором и возвращается
// откатом; смена, которая ломает квест, не сохраняется (проверка мира, правило 4).
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:rpg_builder/content/content_repo.dart';
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
        title: 'Роли ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
  });

  tearDownAll(() => a.from('projects').delete().eq('id', world.id));

  NewCharacter asForm(Character c, {Role? role}) => NewCharacter(
    title: c.title,
    description: c.description,
    role: role ?? c.role,
    locationId: c.locationId,
    loot: c.loot,
    level: c.level,
    hp: c.hp,
    attack: c.attack,
  );

  test('роль и вид меняются через историю; ломающая смена — нет', () async {
    final id = world.id;
    Future<String?> make(ManualEdit Function(dynamic) b) =>
        createManually(repo, id, (w) => b(w));
    expect(
      await make(
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
      ),
      isNull,
    );
    var w = await repo.snapshot(id);
    final kopi = w.locations.single.id;
    expect(
      await make(
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
      ),
      isNull,
    );
    w = await repo.snapshot(id);
    final pick = w.items.single;
    for (final (title, role) in [
      ('Бригадир', Role.npc),
      ('Шахтёр', Role.npc),
    ]) {
      expect(
        await make(
          (w) => createCharacterEdit(
            id,
            w,
            NewCharacter(
              title: title,
              description: '',
              role: role,
              locationId: kopi,
            ),
          ),
        ),
        isNull,
      );
    }
    w = await repo.snapshot(id);
    final brigadir = w.characters.firstWhere((c) => c.title == 'Бригадир');
    final miner = w.characters.firstWhere((c) => c.title == 'Шахтёр');
    expect(
      await make(
        (w) => createQuestEdit(
          id,
          w,
          NewQuest(
            title: 'Обвал',
            description: '',
            giverId: brigadir.id,
            steps: [QuestStep(kind: StepKind.talk, targetId: brigadir.id)],
          ),
        ),
      ),
      isNull,
    );
    w = await repo.snapshot(id);

    // Вид предмета: оружие → прочее, урон уходит.
    final itemErr = await saveManualEdit(
      repo,
      id,
      w,
      editItem(
        id,
        pick,
        const NewItem(
          title: 'Кирка',
          kind: ItemKind.misc,
          rarity: Rarity.common,
          level: 1,
          price: 15,
        ),
      ),
    );
    expect(itemErr, isNull);
    w = await repo.snapshot(id);
    expect((w.items.single.kind, w.items.single.damage), (ItemKind.misc, null));

    // Шахтёр: житель → враг с добычей → житель (добыча уходит), откат возвращает.
    final slugs = {pick.id: pick.slug};
    expect(
      await saveManualEdit(
        repo,
        id,
        w,
        editCharacter(id, miner, asForm(miner, role: Role.enemy), slugs),
      ),
      isNull,
    );
    w = await repo.snapshot(id);
    var m = w.characters.firstWhere((c) => c.id == miner.id);
    expect(m.role, Role.enemy);
    final withLoot = NewCharacter(
      title: m.title,
      description: '',
      role: Role.enemy,
      locationId: kopi,
      loot: [LootDrop(itemId: pick.id, chance: 35)],
    );
    expect(
      await saveManualEdit(repo, id, w, editCharacter(id, m, withLoot, slugs)),
      isNull,
    );
    w = await repo.snapshot(id);
    m = w.characters.firstWhere((c) => c.id == miner.id);
    expect(m.loot.single.chance, 35);
    expect(
      await saveManualEdit(
        repo,
        id,
        w,
        editCharacter(id, m, asForm(m, role: Role.npc), slugs),
      ),
      isNull,
    );
    w = await repo.snapshot(id);
    m = w.characters.firstWhere((c) => c.id == miner.id);
    expect(m.role, Role.npc);
    expect(m.loot, isEmpty);
    final history = await repo.history(id);
    expect(history.first.request, 'Правка вручную: Шахтёр');
    await repo.revertChangeSet(id, history.first.id);
    w = await repo.snapshot(id);
    m = w.characters.firstWhere((c) => c.id == miner.id);
    expect((m.role, m.loot.single.chance), (Role.enemy, 35));

    // Бригадир выдаёт квест — врагом не станет, база не тронута.
    final b = w.characters.firstWhere((c) => c.id == brigadir.id);
    final err = await saveManualEdit(
      repo,
      id,
      w,
      editCharacter(id, b, asForm(b, role: Role.enemy), slugs),
    );
    expect(err, contains('квест выдаёт только житель'));
    w = await repo.snapshot(id);
    expect(w.characters.firstWhere((c) => c.id == brigadir.id).role, Role.npc);
  });

  test('откат смены роли не ломает квест, добавленный позже', () async {
    final id = world.id;
    var w = await repo.snapshot(id);
    final kopi = w.locations.first.id;
    expect(
      await createManually(
        repo,
        id,
        (w) => createCharacterEdit(
          id,
          w,
          NewCharacter(
            title: 'Сторож',
            description: '',
            role: Role.npc,
            locationId: kopi,
          ),
        ),
      ),
      isNull,
    );
    w = await repo.snapshot(id);
    final guard = w.characters.firstWhere((c) => c.title == 'Сторож');
    final giver = w.characters.firstWhere(
      (c) => c.role == Role.npc && c.id != guard.id,
    );
    // A: Сторож стал врагом.
    expect(
      await saveManualEdit(
        repo,
        id,
        w,
        editCharacter(id, guard, asForm(guard, role: Role.enemy), const {}),
      ),
      isNull,
    );
    final setA = (await repo.history(id)).first.id;
    // B: квест «убить Сторожа».
    expect(
      await createManually(
        repo,
        id,
        (w) => createQuestEdit(
          id,
          w,
          NewQuest(
            title: 'Облава',
            description: '',
            giverId: giver.id,
            steps: [
              QuestStep(kind: StepKind.kill, targetId: guard.id, amount: 1),
            ],
          ),
        ),
      ),
      isNull,
    );
    // Откат A вернул бы жителя под «убить» — база отказывает с причиной.
    await expectLater(
      repo.revertChangeSet(id, setA),
      throwsA(predicate((e) => '$e'.contains('роль не меняется'))),
    );
    w = await repo.snapshot(id);
    expect(w.characters.firstWhere((c) => c.id == guard.id).role, Role.enemy);
  });
}
