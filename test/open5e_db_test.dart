// Импорт образца Open5e в НАСТОЯЩЕЙ базе (4.6): планом через apply_change_set — предмет с
// источником, набор в истории с областью «import», правка вручную источник не стирает, откат убирает.
@Tags(['db'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/assistant/history.dart';
import 'package:rpg_builder/content/content_repo.dart';
import 'package:rpg_builder/content/item.dart';
import 'package:rpg_builder/content/manual_edit.dart';
import 'package:rpg_builder/open5e/open5e_import.dart';
import 'package:rpg_builder/worlds/world.dart';
import 'package:rpg_builder/worlds/worlds_repo.dart';
import 'package:supabase/supabase.dart';

import 'assistant_fixtures.dart';
import 'db_helpers.dart';
import 'open5e_test.dart' show warPick;

void main() {
  late SupabaseClient a;
  late World world;
  late SupabaseContentRepo repo;

  setUpAll(() async {
    (a, _) = await twoAuthors();
    repo = SupabaseContentRepo(a);
  });

  setUp(() async {
    world = await SupabaseWorldsRepo(a).create(
      NewWorld(
        title: 'Open5e ${DateTime.now().microsecondsSinceEpoch}',
        setting: '',
        tone: '',
        levelMin: 1,
        levelMax: 10,
      ),
    );
    await fillMines(repo, world.id);
  });
  tearDown(() => a.from('projects').delete().eq('id', world.id));

  Future<Item?> pick() async =>
      (await repo.items(world.id))
          .where((i) => i.slug == 'war_pick')
          .firstOrNull;

  test(
    'образец в базе: импорт с источником → в истории «import» → правка → откат',
    () async {
      final plan = importPlan(warPick(), await repo.snapshot(world.id));
      await repo.applyChangeSet(
        world.id,
        ChangeSetDraft.imported(
          request: plan.summary,
          plan: plan,
          slug: 'war_pick',
        ),
      );
      final item = (await pick())!;
      expect(
        (item.source, item.sourceRef, item.kind, item.damage, item.price),
        ('Open5e', 'srd-2024_war-pick', ItemKind.weapon, 5, 5),
      );
      final set =
          (await a.from('change_sets').select().eq('project_id', world.id))
              .single;
      expect((set['scope_type'], set['scope_slug']), ('import', 'war_pick'));
      expect(
        await a
            .from('generations')
            .select()
            .eq('change_set_id', set['id'] as String),
        isEmpty,
        reason: 'модель не звали — журнала модели нет',
      );

      // Правка вручную меняет цену, источник остаётся.
      await repo.applyManualEdit(
        world.id,
        editItem(
          world.id,
          item,
          const NewItem(
            title: 'War Pick',
            kind: ItemKind.weapon,
            rarity: Rarity.common,
            level: 1,
            damage: 5,
            price: 12,
          ),
        ),
      );
      final edited = (await pick())!;
      expect(
        (edited.price, edited.source, edited.sourceRef),
        (12, 'Open5e', 'srd-2024_war-pick'),
      );

      // Откат правки, потом откат импорта — образца в мире нет.
      final history = await repo.history(world.id);
      for (final s in history.where((s) => s.status == SetStatus.applied)) {
        await repo.revertChangeSet(world.id, s.id);
      }
      expect(await pick(), isNull);
    },
  );
}
