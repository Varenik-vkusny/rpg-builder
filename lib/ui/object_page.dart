// Страница объекта мира: где он, что он, что внутри. Правка — одной кнопкой ✏.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'cover_card.dart';

/// Плитка характеристики: значок, подпись, значение.
class StatTile extends StatelessWidget {
  const StatTile(this.icon, this.label, this.value, {super.key});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 18, color: s.onSurfaceVariant),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

/// Карточка-портрет в ленте «Кто здесь» / «Добыча».
class PortraitCard extends StatelessWidget {
  const PortraitCard({
    super.key,
    required this.icon,
    required this.title,
    this.stats = const [],
    this.onTap,
  });
  final IconData icon;
  final String title;
  final List<(IconData, String)> stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return SizedBox(
      width: 104,
      child: Material(
        color: s.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            child: Column(
              spacing: 6,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: s.surfaceContainerHighest,
                  child: Icon(icon, size: 30, color: s.onSurfaceVariant),
                ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                if (stats.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final (i, v) in stats)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 2,
                          children: [
                            Icon(i, size: 13, color: s.onSurfaceVariant),
                            Text(
                              v,
                              style: TextStyle(
                                fontSize: 12,
                                color: s.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Раздел страницы: заголовок со значком и содержимое (лента, строки).
typedef ObjectSection = ({IconData icon, String title, Widget child});

/// Открывает страницу глубже; если там что-то поменяли — закрывает и эту с `true`,
/// чтобы мир перечитался.
Future<void> openDeeper(BuildContext context, Widget page) async {
  final changed = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => page));
  if (changed == true && context.mounted) Navigator.of(context).pop(true);
}

class ObjectPage extends StatelessWidget {
  const ObjectPage({
    super.key,
    required this.icon,
    required this.title,
    required this.kind,
    required this.edit,
    this.path = const [],
    this.cover = false,
    this.tiles = const [],
    this.description = '',
    this.sections = const [],
  });

  final IconData icon;
  final String title;

  /// Вид объекта словом: «Враг», «Локация», «Редкий предмет».
  final String kind;

  /// Где объект в мире: «Штольня №3».
  final List<String> path;

  /// Локация — большой обложкой, остальные — значком.
  final bool cover;
  final List<StatTile> tiles;
  final String description;
  final List<ObjectSection> sections;

  /// Форма правки; вернула true — объект изменён или удалён.
  final Widget Function() edit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        key: const Key('object-edit'),
        tooltip: 'Править',
        onPressed: () => openDeeper(context, edit()),
        child: const Icon(Symbols.edit_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          if (path.isNotEmpty) _PathLine(path),
          if (cover)
            CoverCard(
              title: title,
              icon: icon,
              hue: CoverCard.hueOf(title),
              caption: kind,
              height: 150,
            )
          else
            _Hero(icon: icon, title: title, kind: kind),
          if (tiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TileGrid(tiles),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
          ],
          for (final sec in sections) ...[
            _SectionHead(sec.icon, sec.title),
            sec.child,
          ],
        ],
      ),
    );
  }
}

/// Где объект в мире: «📍 Штольня №3».
class _PathLine extends StatelessWidget {
  const _PathLine(this.path);
  final List<String> path;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        spacing: 4,
        children: [
          Icon(Symbols.location_on_rounded, size: 16, color: s.primary),
          Expanded(
            child: Text(
              path.join(' › '),
              style: TextStyle(color: s.primary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid(this.tiles);
  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1.25,
    children: tiles,
  );
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.icon, this.title);
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        spacing: 8,
        children: [
          Icon(icon, size: 18, color: s.onSurfaceVariant),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: s.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.icon, required this.title, required this.kind});
  final IconData icon;
  final String title;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(
      spacing: 16,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: s.surfaceContainerHighest,
          child: Icon(icon, size: 38, color: s.onSurfaceVariant),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              Chip(
                label: Text(kind),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Горизонтальная лента карточек.
class Rail extends StatelessWidget {
  const Rail(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 156,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, i) => children[i],
    ),
  );
}
