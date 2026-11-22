import 'package:supabase/supabase.dart';

import 'world.dart';

/// Доступ к мирам. Какие миры видны — решает RLS в базе, а не этот код.
abstract class WorldsRepo {
  Future<List<World>> listMine();
  Future<World> create(NewWorld world);

  /// Меняет свойства своего мира (в историю изменений не идёт).
  Future<World> update(String id, NewWorld world);

  /// Удаляет свой мир со всеми объектами и историей (каскадом в базе).
  Future<void> delete(String id);
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

  @override
  Future<World> update(String id, NewWorld world) async {
    // RLS: чужой мир не виден для правки — строк нет, .single() падает.
    final row = await _client
        .from('projects')
        .update(world.toRow())
        .eq('id', id)
        .select()
        .single();
    return World.fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    final gone = await _client.from('projects').delete().eq('id', id).select();
    if (gone.isEmpty) throw StateError('Мир не найден или он не ваш');
  }
}
