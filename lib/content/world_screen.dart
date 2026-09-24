import 'package:flutter/material.dart';

import '../worlds/world.dart';
import 'content_repo.dart';
import 'location.dart';
import 'new_location_screen.dart';

/// Мир изнутри: его локации.
class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key, required this.world, required this.repo});

  final World world;
  final ContentRepo repo;

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  late Future<List<Location>> _locations = _load();

  Future<List<Location>> _load() => widget.repo.locations(widget.world.id);

  Future<void> _openNewLocation() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            NewLocationScreen(world: widget.world, repo: widget.repo),
      ),
    );
    if (created == true) {
      setState(() {
        _locations = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.world.title)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-location'),
        onPressed: _openNewLocation,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Локация'),
      ),
      body: FutureBuilder<List<Location>>(
        future: _locations,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Не удалось загрузить мир: ${snap.error}'),
            );
          }
          final locations = snap.data!;
          return ListView(
            children: [
              const ListTile(title: Text('Локации')),
              if (locations.isEmpty)
                const ListTile(subtitle: Text('Локаций пока нет')),
              for (final l in locations)
                ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(l.title),
                  subtitle: Text('Уровни ${l.levelMin}–${l.levelMax}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
