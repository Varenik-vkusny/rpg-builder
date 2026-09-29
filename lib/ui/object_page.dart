// Страница объекта мира: где он, что он, что внутри. Правка — одной кнопкой ✏.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'cover_card.dart';
import 'parts.dart';

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
        border: Border.all(color: s.outlineVariant),
      ),
      // Значок и число сверху, подпись снизу во всю ширину: «Здоровье» не режется.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(icon, size: 18, color: s.onSurfaceVariant),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
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
        shape: RoundedRectangleBorder(
          side: BorderSide(color: s.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
            child: Column(
              spacing: 6,
              children: [
                Avatar(icon, size: 56),
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

class ObjectPage extends StatefulWidget {
  const ObjectPage({
    super.key,
    required this.icon,
    required this.title,
    required this.kind,
    required this.edit,
    this.path = const [],
    this.cover = false,
    this.coverSeed,
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

  /// Ключ цвета обложки (slug места); нет — название.
  final String? coverSeed;
  final List<StatTile> tiles;
  final String description;
  final List<ObjectSection> sections;

  /// Форма правки; вернула true — объект изменён или удалён.
  final Widget Function() edit;

  @override
  State<ObjectPage> createState() => _ObjectPageState();
}

class _ObjectPageState extends State<ObjectPage> {
  /// Место: имя только на обложке; в шапке — когда обложка ушла вверх при прокрутке.
  late bool _titleInBar = !widget.cover;

  bool _onScroll(ScrollNotification n) {
    if (widget.cover && n.metrics.axis == Axis.vertical && n.depth == 0) {
      final gone = n.metrics.pixels > _coverHeight;
      if (gone != _titleInBar) setState(() => _titleInBar = gone);
    }
    return false;
  }

  static const _coverHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Scaffold(
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _titleInBar ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: _titleInBar ? Text(w.title) : const SizedBox.shrink(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('object-edit'),
        tooltip: 'Править',
        onPressed: () => openDeeper(context, w.edit()),
        child: const Icon(Symbols.edit_rounded),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            if (w.path.isNotEmpty) _PathLine(w.path),
            if (w.cover)
              CoverCard(
                title: w.title,
                icon: w.icon,
                seed: w.coverSeed ?? w.title,
                caption: w.kind,
                height: _coverHeight,
              )
            else
              _Hero(icon: w.icon, title: w.title, kind: w.kind),
            if (w.tiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TileGrid(w.tiles),
            ],
            if (w.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                w.description,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ],
            for (final sec in w.sections) ...[
              _SectionHead(sec.icon, sec.title),
              sec.child,
            ],
          ],
        ),
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
          Icon(
            Symbols.location_on_rounded,
            size: 16,
            color: s.onSurfaceVariant,
          ),
          Expanded(
            child: Text(
              path.join(' › '),
              style: TextStyle(color: s.onSurfaceVariant, fontSize: 14),
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

  // По три в ряд; высота ряда — по содержимому, чтобы крупный шрифт телефона не вылезал.
  @override
  Widget build(BuildContext context) => Column(
    spacing: 8,
    children: [
      for (var i = 0; i < tiles.length; i += 3)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              for (var k = i; k < i + 3; k++)
                Expanded(child: k < tiles.length ? tiles[k] : const SizedBox()),
            ],
          ),
        ),
    ],
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
    return Row(
      spacing: 16,
      children: [
        Avatar(icon, size: 72),
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
