import 'package:supabase/supabase.dart';

import 'world.dart';

/// Доступ к мирам. Какие миры видны — решает RLS в базе, а не этот код.
abstract class WorldsRepo {
  Future<List<World>> listMine();
  Future<World> create(NewWorld world);
}

class SupabaseWorldsRepo implements WorldsRepo {
  SupabaseWorldsRepo(this._client);

  final SupabaseClient _client;

  @override
  Future<List<World>> listMine() async {
    final rows = await _client
        .from('projects')
        .select()
        .order('created_at', ascending: false);
    return rows.map(World.fromRow).toList();
  }

  @override
  Future<World> create(NewWorld world) async {
    final row = await _client
        .from('projects')
        .insert(world.toRow())
        .select()
        .single();
    return World.fromRow(row);
  }
}
