import 'package:supabase/supabase.dart';

import '../assistant/change_set.dart';
import '../assistant/history.dart';
import '../check/world_check.dart';
import 'character.dart';
import 'event.dart';
import 'item.dart';
import 'location.dart';
import 'manual_edit.dart';
import 'quest.dart';
import 'slug.dart';

/// Где лежит блок места на карте (dp холста при масштабе 1).
typedef Spot = ({double x, double y});

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
  Future<List<Event>> events(String worldId);

  /// Событие, его враги и предметы записываются одной транзакцией.
  Future<Event> createEvent(String worldId, NewEvent event);

  /// План ассистента — одной транзакцией или ничего; набор уходит в журнал.
  Future<void> applyChangeSet(String worldId, ChangeSetDraft draft);

  /// Отклонённый план: мир не меняется, набор пишется в журнал как rejected.
  Future<void> rejectChangeSet(String worldId, ChangeSetDraft draft);

  /// История наборов мира, новые сверху, с операциями «было → стало».
  Future<List<ChangeSetEntry>> history(String worldId);

  /// Что помешает откатить набор: объекты, которые меняли после него.
  Future<List<RevertConflict>> revertConflicts(String worldId, String setId);

  /// Откат — обратный набор одной транзакцией; при конфликте база откажет.
  Future<void> revertChangeSet(String worldId, String setId);

  /// Правка или удаление вручную — набором в историю, одной транзакцией.
  Future<void> applyManualEdit(String worldId, ManualEdit edit);

  /// Раскладка карты: положение блоков по id места. Раскладка автора, не содержимое мира:
  /// мимо истории, отката, плана ИИ и экспорта (VISION §10). Нет записи — место без положения.
  Future<Map<String, Spot>> layout(String worldId);

  /// Автор перетащил блок места — запомнить, где он лежит.
  Future<void> moveLocation(String worldId, String locationId, Spot spot);
}

extension WorldSnapshotLoad on ContentRepo {
  /// Всё содержимое мира разом — снимок для экрана мира и проверки.
  Future<WorldSnapshot> snapshot(String worldId) async {
    final (locations, items, characters, quests, events) = await (
      this.locations(worldId),
      this.items(worldId),
      this.characters(worldId),
      this.quests(worldId),
      this.events(worldId),
    ).wait;
    return WorldSnapshot(
      locations: locations,
      items: items,
      characters: characters,
      quests: quests,
      events: events,
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
      '*, quest_steps(position, kind, character_id, item_id, location_id, event_id,'
      ' amount),'
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

  static const _eventColumns =
      '*, event_enemies(id, character_id, amount), event_items(id, item_id)';

  @override
  Future<List<Event>> events(String worldId) async {
    final rows = await _client
        .from('events')
        .select(_eventColumns)
        .eq('project_id', worldId)
        .order('created_at');
    return rows.map(Event.fromRow).toList();
  }

  @override
  Future<Event> createEvent(String worldId, NewEvent event) async {
    final slug = uniqueSlug(event.title, await _slugs('events', worldId));
    final created = await _client
        .rpc('create_event', params: event.toParams(worldId, slug))
        .select('id')
        .single();
    // Отдельным запросом: в ответе самой функции её связей ещё не видно,
    // а правке и откату нужны их id.
    final row = await _client
        .from('events')
        .select(_eventColumns)
        .eq('id', created['id'] as String)
        .single();
    return Event.fromRow(row);
  }

  @override
  Future<void> applyChangeSet(String worldId, ChangeSetDraft draft) =>
      _client.rpc('apply_change_set', params: draft.toParams(worldId));

  @override
  Future<void> rejectChangeSet(String worldId, ChangeSetDraft draft) =>
      _client.rpc('reject_change_set', params: draft.toParams(worldId));

  @override
  Future<List<ChangeSetEntry>> history(String worldId) async {
    final rows = await _client
        .from('change_sets')
        .select('*, change_ops(*)')
        .eq('project_id', worldId)
        .order('created_at', ascending: false);
    return rows.map(ChangeSetEntry.fromRow).toList();
  }

  @override
  Future<List<RevertConflict>> revertConflicts(
    String worldId,
    String setId,
  ) async {
    final rows = await _client.rpc(
      'change_set_conflicts',
      params: {'p_set': setId},
    );
    return [
      for (final r in rows as List)
        RevertConflict.fromRow(r as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> revertChangeSet(String worldId, String setId) => _client.rpc(
    'revert_change_set',
    params: {'p_project_id': worldId, 'p_set': setId},
  );

  @override
  Future<void> applyManualEdit(String worldId, ManualEdit edit) => _client.rpc(
    'apply_manual_edit',
    params: {
      'p_project_id': worldId,
      'p_slug': edit.slug,
      'p_title': edit.title,
      'p_ops': edit.ops,
    },
  );

  @override
  Future<Map<String, Spot>> layout(String worldId) async {
    final rows = await _client
        .from('location_layout')
        .select('location_id, x, y')
        .eq('project_id', worldId);
    return {
      for (final r in rows)
        r['location_id'] as String: (
          x: (r['x'] as num).toDouble(),
          y: (r['y'] as num).toDouble(),
        ),
    };
  }

  @override
  Future<void> moveLocation(String worldId, String locationId, Spot spot) =>
      _client.from('location_layout').upsert({
        'location_id': locationId,
        'project_id': worldId,
        'x': spot.x,
        'y': spot.y,
      });

  Future<List<String>> _slugs(String table, String worldId) async {
    final rows = await _client
        .from(table)
        .select('slug')
        .eq('project_id', worldId);
    return [for (final r in rows) r['slug'] as String];
  }
}
