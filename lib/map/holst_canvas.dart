// Холст мира (5е): слои холста — сетка, места, нити, жетоны и двери, подписи, полка.
// Нити считаются в координатах экрана: полка не масштабируется вместе с миром.
part of 'holst_screen.dart';

extension _Canvas on _HolstState {
  Widget _canvas(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    final colors = ThreadColors(
      hot: s.onSurface,
      isNew: c.ok,
      changed: c.change,
      error: s.error,
      ink: s.surfaceContainerLowest,
    );
    final repaint = Listenable.merge([_view, _shelfScroll]);
    return LayoutBuilder(
      builder: (context, box) {
        _vp = box.biggest;
        if (!_framed && _scene.places.isNotEmpty) {
          _framed = true;
          _view.value = nearView(_vp, _scene.bounds);
        }
        return ClipRect(
          child: DragTarget<NewKind>(
            onMove: _dragOver,
            onLeave: (_) => _set(() => _dropPlace = null),
            onAcceptWithDetails: _drop,
            builder: (context, _, _) => GestureDetector(
              key: const Key('holst-canvas'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _setSel(null),
              onScaleStart: _scaleStart,
              onScaleUpdate: _scaleUpdate,
              child: Stack(
                key: _canvasKey,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DotGrid(_view, s.outline.withValues(alpha: .3)),
                    ),
                  ),
                  _layer(_placesLayer(context)),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ThreadPainter(
                          threads: _threads,
                          colors: colors,
                          labels: false,
                          obstacles: () => const [],
                          textStyle: const TextStyle(),
                          repaint: repaint,
                        ),
                      ),
                    ),
                  ),
                  if (!_far) _layer(_tokensLayer(context)),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ThreadPainter(
                          threads: _threads,
                          colors: colors,
                          labels: true,
                          obstacles: _obstacles,
                          textStyle: const TextStyle(
                            fontFamily: 'GolosText',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          repaint: repaint,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: HolstShelf(
                      tokens: _scene.shelf,
                      keys: _shelfKeys,
                      controller: _shelfScroll,
                      chip: (t) => _token(t, null, width: null),
                    ),
                  ),
                  if (_snack case final sn?)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: HolstShelf.height + 8,
                      child: HolstSnack(data: sn),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Слой в координатах мира: едет и масштабируется вместе с холстом.
  Widget _layer(Widget child) => Positioned(
    left: 0,
    top: 0,
    child: AnimatedBuilder(
      animation: _view,
      builder: (_, child) => Transform(transform: _view.value, child: child),
      child: SizedBox(
        width: _scene.bounds.right + 24,
        height: _scene.bounds.bottom + 24,
        child: child,
      ),
    ),
  );

  Set<String> get _near => neighbours(_sel, _links);

  Widget _placesLayer(BuildContext context) {
    final near = _near;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final p in _scene.places)
          Positioned.fromRect(
            rect: p.rect,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _sel != null && !p.tokens.any((t) => near.contains(t.id))
                  ? .45
                  : 1,
              child: GestureDetector(
                // Издалека нажатие на место — приблизить его.
                onTap: _far
                    ? () => _flyTo(centerOn(_vp, p.rect, 1, HolstShelf.height))
                    : null,
                child: Semantics(
                  container: true,
                  label: p.place.title,
                  child: PlaceCard(
                    key: Key('hplace-${p.place.slug}'),
                    place: p,
                    far: _far,
                    stats: farStats(_w, p),
                    problems: placeProblems(_problems, p),
                    mark: _marks[p.place.id] ?? Mark.none,
                    drop: _dropPlace == p.place.id,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tokensLayer(BuildContext context) {
    final dim = _sel != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final p in _scene.places) ...[
          for (final t in p.tokens)
            Positioned.fromRect(
              rect: t.rect,
              child: _token(t, placeHue(context, p.place)),
            ),
          for (final d in p.doors)
            Positioned.fromRect(
              rect: d.rect,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: dim ? .28 : 1,
                child: DoorTile(
                  key: Key('hdoor-${d.place.slug}'),
                  door: d,
                  onEnter: () => _go([
                    ...ancestorsOf(_w.locations, d.place).reversed,
                    d.place,
                  ]),
                ),
              ),
            ),
          if (p.overflowRect case final r?)
            Positioned.fromRect(
              rect: r,
              child: OverflowTile(
                key: Key('hmore-${p.place.slug}'),
                count: p.overflow + 1,
              ),
            ),
        ],
      ],
    );
  }

  /// Жетон на холсте или на полке: касание — выбрать, его нити светятся, остальное гаснет.
  Widget _token(HolstToken t, Color? hue, {double? width = 148}) {
    final near = _near;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _sel != null && !near.contains(t.id) ? .28 : 1,
      child: Semantics(
        button: true,
        selected: _sel == t.id,
        label: '${kindName(t.kind)} ${t.title}',
        child: GestureDetector(
          key: Key('token-${t.slug}'),
          onTap: () => _tapToken(t.id),
          child: TokenTile(
            token: t,
            hue: hue,
            width: width,
            selected: _sel == t.id,
            mark: _marks[t.id] ?? Mark.none,
            warn: _warns.containsKey(t.id),
          ),
        ),
      ),
    );
  }

  /// Где жетон на экране (в координатах холста): на уровне — из мира, на полке — по ключу.
  /// Объект другого уровня — null: его нить не рисуется, связь есть в нижней строке.
  ({Rect rect, bool shelf})? _rectOf(String id) {
    for (final p in _scene.places) {
      for (final t in p.tokens) {
        if (t.id == id) {
          return (rect: toScreen(_view.value, t.rect), shelf: false);
        }
      }
      if (p.place.id == id) {
        final head = Rect.fromLTWH(p.rect.left, p.rect.top, p.rect.width, 32);
        return (rect: toScreen(_view.value, head), shelf: false);
      }
    }
    final box = _shelfKeys[id]?.currentContext?.findRenderObject();
    final canvas = _canvasKey.currentContext?.findRenderObject();
    if (box is! RenderBox || canvas is! RenderBox || !box.attached) return null;
    final o = canvas.globalToLocal(box.localToGlobal(Offset.zero));
    return (rect: o & box.size, shelf: true);
  }

  /// Нити по требованию: в покое их нет, видны только у выбранного объекта.
  List<ThreadSpec> _threads() {
    if (_far || _sel == null) return const [];
    return [
      for (final l in _links)
        if (l.touches(_sel!))
          if ((_rectOf(l.a), _rectOf(l.b)) case (final a?, final b?))
            ThreadSpec(
              a: a.rect,
              b: b.rect,
              aShelf: a.shelf,
              bShelf: b.shelf,
              label: l.label,
              loot: l.loot,
              tone: ThreadTone.hot,
            ),
    ];
  }

  /// Подпись не ложится на блоки: жетоны, двери и полку целиком.
  List<Rect> _obstacles() {
    final m = _view.value;
    return [
      for (final p in _scene.places) ...[
        for (final t in p.tokens) toScreen(m, t.rect),
        for (final d in p.doors) toScreen(m, d.rect),
      ],
      Rect.fromLTWH(
        0,
        _vp.height - HolstShelf.height,
        _vp.width,
        HolstShelf.height,
      ),
    ];
  }

  // Сдвиг одним пальцем и масштаб двумя — вокруг точки между пальцами.
  void _scaleStart(ScaleStartDetails d) {
    _fly.stop();
    _start = _view.value.clone();
    _focal0 = d.localFocalPoint;
  }

  void _scaleUpdate(ScaleUpdateDetails d) {
    final start = _start;
    if (start == null) return;
    _view.value = clampView(
      zoomAround(start, _focal0, d.localFocalPoint, d.scale),
      _vp,
      _scene.bounds,
    );
  }
}
