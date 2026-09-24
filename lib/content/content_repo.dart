import 'package:supabase/supabase.dart';

import '../assistant/change_set.dart';
import '../check/world_check.dart';
import 'character.dart';
import 'item.dart';
import 'location.dart';
import 'quest.dart';
import 'slug.dart';

/// Содержимое одного мира. Чьё содержимое видно — решает RLS в базе.
abstract class ContentRepo {
  Future<List<Location>> locations(String worldId);
  Future<Location> createLocation(String worldId, NewLocation location);
  Future<List<Item>> items(String worldId);
  Future<Item> createItem(String worldId, NewItem item);
  Future<List<Character>> characters(String worldId);

  /// Персонаж и его добыча записываются одной транзакцией.
  Future<Character> createCharacter(String worldId, NewCharacter character);
  Future<List<Quest>> quests(String worldId);

  /// Квест, его шаги и награды записываются одной транзакцией.
  Future<Quest> createQuest(String worldId, NewQuest quest);

  /// План ассистента — одной транзакцией или ничего; набор уходит в журнал.
  Future<void> applyChangeSet(String worldId, ChangeSetDraft draft);
}

extension WorldSnapshotLoad on ContentRepo {
  /// Всё содержимое мира разом — снимок для экрана мира и проверки.
  Future<WorldSnapshot> snapshot(String worldId) async {
    final (locations, items, characters, quests) = await (
      this.locations(worldId),
      this.items(worldId),
      this.characters(worldId),
      this.quests(worldId),
    ).wait;
    return WorldSnapshot(
      locations: locations,
      items: items,
      characters: characters,
      quests: quests,
    );
  }
}

class SupabaseContentRepo implements ContentRepo {
  SupabaseContentRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Location>> locations(String worldId) async {
    final rows = await _client
        .from('locations')
        .select()
        .eq('project_id', worldId)
        .order('created_at');
    return rows.map(Location.fromRow).toList();
  }

  @override
  Future<Location> createLocation(String worldId, NewLocation location) async {
    final slug = uniqueSlug(location.title, await _slugs('locations', worldId));
    final row = await _client
        .from('locations')
        .insert(location.toRow(worldId, slug))
        .select()
        .single();
    return Location.fromRow(row);
  }

  @override
  Future<List<Item>> items(String worldId) async {
    final rows = await _client
        .from('items')
        .select()
        .eq('project_id', worldId)
        .order('created_at');
    return rows.map(Item.fromRow).toList();
  }

  @override
  Future<Item> createItem(String worldId, NewItem item) async {
    final slug = uniqueSlug(item.title, await _slugs('items', worldId));
    final row = await _client
        .from('items')
        .insert(item.toRow(worldId, slug))
        .select()
        .single();
    return Item.fromRow(row);
  }

  @override
  Future<List<Character>> characters(String worldId) async {
    final rows = await _client
        .from('characters')
        .select('*, loot(item_id, chance)')
        .eq('project_id', worldId)
        .order('created_at');
    return rows.map(Character.fromRow).toList();
  }

  @override
  Future<Character> createCharacter(
    String worldId,
    NewCharacter character,
  ) async {
    final slug = uniqueSlug(
      character.title,
      await _slugs('characters', worldId),
    );
    final created = await _client
        .rpc('create_character', params: character.toParams(worldId, slug))
        .select('*, loot(item_id, chance)')
        .single();
    return Character.fromRow(created);
  }

  static const _questColumns =
      '*, quest_steps(position, kind, character_id, item_id, location_id, amount),'
      ' quest_rewards(item_id)';

  @override
  Future<List<Quest>> quests(String worldId) async {
    final rows = await _client
        .from('quests')
        .select(_questColumns)
        .eq('project_id', worldId)
        .order('created_at');
    return rows.map(Quest.fromRow).toList();
  }

  @override
  Future<Quest> createQuest(String worldId, NewQuest quest) async {
    final slug = uniqueSlug(quest.title, await _slugs('quests', worldId));
    final created = await _client
        .rpc('create_quest', params: quest.toParams(worldId, slug))
        .select(_questColumns)
        .single();
    return Quest.fromRow(created);
  }

  @override
  Future<void> applyChangeSet(String worldId, ChangeSetDraft draft) =>
      _client.rpc('apply_change_set', params: draft.toParams(worldId));

  Future<List<String>> _slugs(String table, String worldId) async {
    final rows = await _client
        .from(table)
        .select('slug')
        .eq('project_id', worldId);
    return [for (final r in rows) r['slug'] as String];
  }
}
