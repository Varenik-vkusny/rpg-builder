import 'package:supabase/supabase.dart';

import 'location.dart';
import 'slug.dart';

/// Содержимое одного мира. Чьё содержимое видно — решает RLS в базе.
abstract class ContentRepo {
  Future<List<Location>> locations(String worldId);
  Future<Location> createLocation(String worldId, NewLocation location);
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

  Future<List<String>> _slugs(String table, String worldId) async {
    final rows = await _client
        .from(table)
        .select('slug')
        .eq('project_id', worldId);
    return [for (final r in rows) r['slug'] as String];
  }
}
