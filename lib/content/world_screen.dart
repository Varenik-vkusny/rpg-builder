import 'package:flutter/material.dart';

import '../worlds/world.dart';
import 'character.dart';
import 'content_repo.dart';
import 'item.dart';
import 'location.dart';
import 'new_character_screen.dart';
import 'new_item_screen.dart';
import 'new_location_screen.dart';
import 'new_quest_screen.dart';
import 'quest.dart';

/// Всё содержимое мира, загруженное разом.
class _Content {
  const _Content(this.locations, this.items, this.characters, this.quests);

  final List<Location> locations;
  final List<Item> items;
  final List<Character> characters;
  final List<Quest> quests;

  /// Названия всех объектов мира по id — для ссылок в строках списка.
  Map<String, String> get titles => {
    for (final l in locations) l.id: l.title,
    for (final i in items) i.id: i.title,
    for (final c in characters) c.id: c.title,
  };
}

/// Мир изнутри: локации, предметы, персонажи и квесты, у каждого раздела своя кнопка «+».
class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key, required this.world, required this.repo});

  final World world;
  final ContentRepo repo;

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  late Future<_Content> _content = _load();

  Future<_Content> _load() async {
    final id = widget.world.id;
    final (locations, items, characters, quests) = await (
      widget.repo.locations(id),
      widget.repo.items(id),
      widget.repo.characters(id),
      widget.repo.quests(id),
    ).wait;
    return _Content(locations, items, characters, quests);
  }

  /// Открывает форму создания; после сохранения перечитывает мир.
  Future<void> _open(Widget form) async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => form));
    if (created == true) {
      setState(() {
        _content = _load();
      });
    }
  }

  Widget _header(String title, Key addKey, String tooltip, Widget form) =>
      ListTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: IconButton(
          key: addKey,
          tooltip: tooltip,
          icon: const Icon(Icons.add),
          onPressed: () => _open(form),
        ),
      );

  /// Квест в списке: выдающий, шаги по порядку, награды — строками.
  Widget _questTile(Quest q, Map<String, String> titles) => ListTile(
    leading: const Icon(Icons.flag),
    title: Text(q.title),
    subtitle: Text(q.lines(titles).join('\n')),
    isThreeLine: true,
  );

  @override
  Widget build(BuildContext context) {
    final world = widget.world;
    final repo = widget.repo;
    return Scaffold(
      appBar: AppBar(title: Text(world.title)),
      body: FutureBuilder<_Content>(
        future: _content,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Не удалось загрузить мир: ${snap.error}'),
            );
          }
          final c = snap.data!;
          return ListView(
            children: [
              _header(
                'Локации',
                const Key('new-location'),
                'Новая локация',
                NewLocationScreen(world: world, repo: repo),
              ),
              if (c.locations.isEmpty)
                const ListTile(subtitle: Text('Локаций пока нет')),
              for (final l in c.locations)
                ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(l.title),
                  subtitle: Text('Уровни ${l.levelMin}–${l.levelMax}'),
                ),
              const Divider(),
              _header(
                'Предметы',
                const Key('new-item'),
                'Новый предмет',
                NewItemScreen(world: world, repo: repo),
              ),
              if (c.items.isEmpty)
                const ListTile(subtitle: Text('Предметов пока нет')),
              for (final i in c.items)
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(i.title),
                  subtitle: Text(i.summary),
                ),
              const Divider(),
              _header(
                'Персонажи',
                const Key('new-character'),
                'Новый персонаж',
                NewCharacterScreen(
                  world: world,
                  repo: repo,
                  locations: c.locations,
                  items: c.items,
                ),
              ),
              if (c.characters.isEmpty)
                const ListTile(subtitle: Text('Персонажей пока нет')),
              for (final ch in c.characters)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(ch.title),
                  subtitle: Text(
                    ch.summary(
                      {for (final l in c.locations) l.id: l.title},
                      {for (final i in c.items) i.id: i.title},
                    ),
                  ),
                ),
              const Divider(),
              _header(
                'Квесты',
                const Key('new-quest'),
                'Новый квест',
                NewQuestScreen(
                  world: world,
                  repo: repo,
                  locations: c.locations,
                  items: c.items,
                  characters: c.characters,
                ),
              ),
              if (c.quests.isEmpty)
                const ListTile(subtitle: Text('Квестов пока нет')),
              for (final q in c.quests) _questTile(q, c.titles),
            ],
          );
        },
      ),
    );
  }
}
