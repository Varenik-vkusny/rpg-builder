// Страница объекта мира: где он, что он, что внутри. Правка — одной кнопкой ✏.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import 'cells.dart';
import 'cover_card.dart';
import 'portraits.dart';

export 'portraits.dart';
export 'rail.dart';

/// Раздел страницы: заголовок со значком, число плашкой и содержимое (лента, строки).
/// Пустой [title] без [count] — раздел без заголовка.
class ObjectSection {
  const ObjectSection({
    required this.icon,
    required this.title,
    required this.child,
    this.count,
  });
  final IconData icon;
  final String title;
  final Widget child;
  final int? count;
}

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
    required this.edit,
    required this.help,
    this.path = const [],
    this.pathKey,
    this.cells = const [],
    this.cover = false,
    this.coverSeed,
    this.tiles = const [],
    this.description = '',
    this.sections = const [],
  });

  final IconData icon;
  final String title;

  /// Свойства объекта плашками: вид, редкость, уровень (без склеек «·»).
  final List<CellSpec> cells;

  /// Где объект в мире: «Штольня №3».
  final List<String> path;

  /// Ключ строки пути — для тестов.
  final Key? pathKey;

  /// Локация — большой обложкой, остальные — значком.
  final bool cover;

  /// Ключ цвета обложки (slug места); нет — название.
  final String? coverSeed;
  final List<StatTile> tiles;
  final String description;
  final List<ObjectSection> sections;

  /// Ключ справки экрана: «?» в шапке.
  final String help;

  /// Форма правки; вернула true — объект изменён или удалён.
  final Widget Function() edit;

  @override
  State<ObjectPage> createState() => _ObjectPageState();
}

class _ObjectPageState extends State<ObjectPage> {
  /// Имя один раз: у места на обложке, у остальных в блоке под шапкой; в шапке оно
  /// появляется, только когда обложка ушла вверх при прокрутке.
  bool _titleInBar = false;

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
        actions: [HelpAction(w.help)],
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
          // Сверху отступ: обложка и значок не липнут к шапке (владелец 18.11).
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (w.cover) ...[
              if (w.path.isNotEmpty) _PathLine(w.path, key: w.pathKey),
              CoverCard(
                title: w.title,
                icon: w.icon,
                seed: w.coverSeed ?? w.title,
                height: _coverHeight,
              ),
              if (w.cells.isNotEmpty) ...[
                const SizedBox(height: 10),
                Cells(w.cells),
              ],
            ] else
              _Hero(
                icon: w.icon,
                title: w.title,
                cells: [
                  if (w.path.isNotEmpty)
                    cellSpec(Symbols.landscape_rounded, w.path.join(' › ')),
                  ...w.cells,
                ],
                pathKey: w.pathKey,
              ),
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
            for (final sec in w.sections) ...[_SectionHead(sec), sec.child],
          ],
        ),
      ),
    );
  }
}

/// Где объект в мире: «📍 Штольня №3».
class _PathLine extends StatelessWidget {
  const _PathLine(this.path, {super.key});
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
  const _SectionHead(this.sec);
  final ObjectSection sec;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    if (sec.title.isEmpty && sec.count == null) {
      return const SizedBox(height: 16);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        spacing: 8,
        children: [
          Icon(sec.icon, size: 18, color: s.onSurfaceVariant),
          Text(
            sec.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: s.onSurfaceVariant,
            ),
          ),
          if (sec.count case final n?) _CountBadge(n),
        ],
      ),
    );
  }
}

/// Число в заголовке раздела: плашка, а не «· 3» через точку.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      key: const Key('section-count'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      color: s.surfaceContainerHighest,
      child: Text(
        '$n',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.icon,
    required this.title,
    required this.cells,
    this.pathKey,
  });
  final IconData icon;
  final String title;
  final List<CellSpec> cells;
  final Key? pathKey;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(
      spacing: 14,
      children: [
        Container(
          width: 72,
          height: 72,
          color: s.surfaceContainerHighest,
          child: Icon(icon, size: 40, color: s.onSurface),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                title,
                key: const Key('object-title'),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600, height: 1.15),
              ),
              if (cells.isNotEmpty)
                KeyedSubtree(key: pathKey, child: Cells(cells)),
            ],
          ),
        ),
      ],
    );
  }
}
