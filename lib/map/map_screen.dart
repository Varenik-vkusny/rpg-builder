// Карта-холст (5а.3–5а.5): места мира — блоки на графитовом поле с точечной сеткой; поле
// двигается и масштабируется пальцами, как холст Figma. Нажатие на блок — страница места,
// долгое нажатие — перетащить, угловая кнопка — войти: холст уровнем ниже, путь сверху.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../content/location.dart';
import '../content/world_pages.dart';
import '../ui/object_page.dart';
import '../worlds/world.dart';
import 'map_model.dart';
import 'block_drag.dart';
import 'map_parts.dart';
import 'place_block.dart';

/// Поле вокруг блоков, чтобы крайний блок не прилипал к краю экрана.
const _pad = 16.0;

/// Запас холста справа и снизу — есть куда утащить блок.
const _room = 480.0;

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.snapshot,
  });

  final World world;
  final ContentRepo repo;
  final WorldSnapshot snapshot;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  final _view = TransformationController();
  late final _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Animation<Matrix4>? _flight;
  Size? _viewport;

  /// Сохранённая раскладка всего мира; null — ещё грузится.
  Map<String, Spot>? _saved;

  /// Места, в которые вошли: пусто — верхний уровень (5а.5).
  List<Location> _path = const [];

  /// Где стоят блоки текущего уровня (единицы холста).
  Map<String, Offset> _spots = const {};

  /// Блок, который тащат, и откуда его подняли.
  String? _dragging;
  Offset _origin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _fly.addListener(() {
      if (_flight case final f?) _view.value = f.value;
    });
    widget.repo.layout(widget.world.id).then((saved) {
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _spots = placeLevel(_level, saved);
      });
    });
  }

  @override
  void dispose() {
    _fly.dispose();
    _view.dispose();
    super.dispose();
  }

  WorldSnapshot get _w => widget.snapshot;
  List<Location> get _level =>
      levelOf(_w.locations, _path.isEmpty ? null : _path.last.id);

  /// Перейти на уровень: [path] — места от верхнего до того, в которое вошли.
  void _go(List<Location> path) => setState(() {
    _path = path;
    _spots = placeLevel(_level, _saved ?? const {});
    _dragging = null;
    _viewport = null; // новый уровень — снова весь в кадре
  });

  /// Сколько места занимают блоки уровня (с полем) — по нему кадр «показать всё».
  Size _content(Iterable<Offset> spots) {
    var r = Rect.zero;
    for (final o in spots) {
      r = r.expandToInclude(o & blockSize);
    }
    return Size(r.width + 2 * _pad, r.height + 2 * _pad);
  }

  void _move(String id, Offset delta) => setState(() {
    final o = _origin + delta;
    _spots = {..._spots, id: Offset(o.dx < 0 ? 0 : o.dx, o.dy < 0 ? 0 : o.dy)};
  });

  /// Отпустил блок — к сетке 8 dp и в раскладку; не сохранилось — блок на прежнее место.
  Future<void> _drop(String id) async {
    final o = _spots[id]!;
    final snapped = Offset(
      (o.dx / 8).roundToDouble() * 8,
      (o.dy / 8).roundToDouble() * 8,
    );
    final back = _origin;
    setState(() {
      _spots = {..._spots, id: snapped};
      _dragging = null;
    });
    try {
      await widget.repo.moveLocation(widget.world.id, id, (
        x: snapped.dx,
        y: snapped.dy,
      ));
      _saved = {...?_saved, id: (x: snapped.dx, y: snapped.dy)};
    } catch (_) {
      if (!mounted) return;
      setState(() => _spots = {..._spots, id: back});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось запомнить, где лежит блок. Проверь связь'),
        ),
      );
    }
  }

  /// Все блоки уровня в кадре по центру: мало мест — крупнее (до 1.3), чтобы по блоку было
  /// легко попасть; много — мельче, но не меньше 0.5.
  Matrix4 _fit(Size canvas, Size viewport) {
    final k = math
        .min(viewport.width / canvas.width, viewport.height / canvas.height)
        .clamp(.5, 1.3);
    final dx = (viewport.width - canvas.width * k) / 2;
    final dy = (viewport.height - canvas.height * k) / 2;
    return Matrix4.identity()
      ..translateByDouble(math.max(dx, 0), math.max(dy, 0), 0, 1)
      ..scaleByDouble(k, k, 1, 1);
  }

  /// Плавно показать весь уровень.
  void _showAll(Size canvas) {
    final vp = _viewport;
    if (vp == null) return;
    _flight = Matrix4Tween(
      begin: _view.value,
      end: _fit(canvas, vp),
    ).animate(CurvedAnimation(parent: _fly, curve: Curves.easeOutCubic));
    _fly.forward(from: 0);
  }

  Future<void> _openPlace(BuildContext context, Location location) =>
      openDeeper(
        context,
        WorldPages(widget.world, widget.repo, _w).location(location),
      );

  @override
  Widget build(BuildContext context) {
    final level = _level;
    final spots = _spots;
    final content = _content(spots.values);
    final canvas = Size(content.width + _room, content.height + _room);
    final problems = checkWorld(_w);
    // Поднятый блок рисуется последним — поверх соседей.
    final order = [
      ...level.where((l) => l.id != _dragging),
      ...level.where((l) => l.id == _dragging),
    ];
    // «Назад» с уровня ниже — на уровень вверх; с верхнего — выход из карты.
    return PopScope(
      canPop: _path.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_path.sublist(0, _path.length - 1));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Карта'),
          actions: [
            if (level.isNotEmpty)
              IconButton(
                key: const Key('map-fit'),
                tooltip: 'Показать всё',
                icon: const Icon(Symbols.fit_screen_rounded),
                onPressed: () => _showAll(content),
              ),
          ],
        ),
        body: Column(
          children: [
            if (_path.isNotEmpty)
              MapPath(path: _path, onGo: (keep) => _go(_path.sublist(0, keep))),
            Expanded(
              // Новый уровень проявляется и чуть приближается — как шаг внутрь места.
              // Один холст за раз: у уровней общий пульт масштаба (_view).
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_path.map((l) => l.id).join('/')),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.scale(scale: .96 + .04 * v, child: child),
                ),
                child: _body(level, spots, content, canvas, problems, order),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    List<Location> level,
    Map<String, Offset> spots,
    Size content,
    Size canvas,
    List<Problem> problems,
    List<Location> order,
  ) => level.isEmpty
      ? (_path.isEmpty
            ? const EmptyWorld()
            : EmptyLevel(place: _path.last, depth: _path.length))
      : _saved == null
      ? const Center(child: CircularProgressIndicator())
      : LayoutBuilder(
          builder: (context, box) {
            final vp = box.biggest;
            if (_viewport == null) _view.value = _fit(content, vp);
            _viewport = vp;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: DotGrid(
                      _view,
                      Theme.of(context).colorScheme.outline
                          .withValues(alpha: .3),
                    ),
                  ),
                ),
                InteractiveViewer(
                  key: const Key('map-canvas'),
                  transformationController: _view,
                  constrained: false,
                  boundaryMargin: EdgeInsets.symmetric(
                    horizontal: vp.width * .75,
                    vertical: vp.height * .75,
                  ),
                  minScale: .35,
                  maxScale: 2.5,
                  onInteractionStart: (_) => _fly.stop(),
                  child: SizedBox.fromSize(
                    size: canvas,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final l in order)
                          Positioned(
                            key: ValueKey(l.id),
                            left: _pad + spots[l.id]!.dx,
                            top: _pad + spots[l.id]!.dy,
                            child: BlockDrag(
                              onStart: () => setState(() {
                                _dragging = l.id;
                                _origin = spots[l.id]!;
                              }),
                              onMove: (d) => _move(l.id, d),
                              onDrop: () => _drop(l.id),
                              child: RepaintBoundary(
                                child: PlaceBlock(
                                  key: Key('place-${l.slug}'),
                                  place: l,
                                  stats: placeStats(_w, l, problems),
                                  onTap: () => _openPlace(context, l),
                                  onEnter: () => _go([..._path, l]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
}
