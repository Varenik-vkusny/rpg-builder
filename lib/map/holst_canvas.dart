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
                  if (_drag case final g?)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: TempLine(
                            from: _rectOf(g.from)?.rect.center ?? g.at,
                            to: g.at,
                            color: s.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ?_linkPopup(),
                  ?_markSheet(),
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
        for (final p in [
          ..._scene.places.where((p) => _lift?.id != p.place.id),
          ..._scene.places.where((p) => _lift?.id == p.place.id),
        ])
          AnimatedPositioned.fromRect(
            key: ValueKey('pl-${p.place.id}'),
            rect: _shownPlace(p),
            duration: _flyTime(p.place.id),
            curve: Curves.easeInOutCubic,
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
                // В «Строить» место можно поднять и бросить в другое место.
                onLongPressStart: _mode == HolstMode.build
                    ? (d) =>
                          _liftStart(p.place.id, true, p.rect, d.globalPosition)
                    : null,
                onLongPressMoveUpdate: _mode == HolstMode.build
                    ? (d) => _liftMove(d.globalPosition)
                    : null,
                onLongPressEnd: _mode == HolstMode.build
                    ? (_) => _liftEnd()
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
                    drop: _dropPlace == p.place.id || _lift?.id == p.place.id,
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
          for (final d in p.doors)
            Positioned.fromRect(
              rect: _shownIn(p.place.id, d.rect),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: dim ? .28 : 1,
                child: DoorTile(
                  key: Key('hdoor-${d.place.slug}'),
                  door: d,
                  drop: _dropPlace == d.place.id,
                  onEnter: () => _go([
                    ...ancestorsOf(_w.locations, d.place).reversed,
                    d.place,
                  ]),
                ),
              ),
            ),
          if (p.overflowRect case final r?)
            Positioned.fromRect(
              rect: _shownIn(p.place.id, r),
              child: OverflowTile(
                key: Key('hmore-${p.place.slug}'),
                count: p.overflow + 1,
              ),
            ),
        ],
        // Жетоны — поверх дверей; поднятые и летящие — поверх всех.
        for (final (t, hue) in _ordered(context))
          AnimatedPositioned.fromRect(
            key: ValueKey('tk-${t.id}'),
            rect: _shown(t),
            duration: _flyTime(t.id),
            curve: Curves.easeInOutCubic,
            child: _token(t, hue),
          ),
      ],
    );
  }

  /// Жетоны уровня с цветом их места: поднятый и летящие — в конце, чтобы быть сверху.
  List<(HolstToken, Color)> _ordered(BuildContext context) {
    final all = [
      for (final p in _scene.places)
        for (final t in p.tokens) (t, placeHue(context, p.place)),
    ];
    bool top((HolstToken, Color) x) =>
        _lift?.id == x.$1.id || _flying.containsKey(x.$1.id);
    return [...all.where((x) => !top(x)), ...all.where(top)];
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
          // В «Строить» палец, поведённый от объекта, тянет нить.
          onPanStart: _mode == HolstMode.build
              ? (d) => _threadStart(t.id, d)
              : null,
          onPanUpdate: _mode == HolstMode.build ? _threadMove : null,
          onPanEnd: _mode == HolstMode.build ? (_) => _threadEnd() : null,
          onPanCancel: _mode == HolstMode.build
              ? () => _set(() => _drag = null)
              : null,
          // Держать — поднять и перенести (только объекты мест, не полки).
          onLongPressStart:
              _mode == HolstMode.build && t.placeId != null && width != null
              ? (d) => _liftStart(t.id, false, t.rect, d.globalPosition)
              : null,
          onLongPressMoveUpdate: _mode == HolstMode.build && width != null
              ? (d) => _liftMove(d.globalPosition)
              : null,
          onLongPressEnd: _mode == HolstMode.build && width != null
              ? (_) => _liftEnd()
              : null,
          child: TokenTile(
            token: t,
            hue: hue,
            width: width,
            selected: _sel == t.id,
            mark: _marks[t.id] ?? Mark.none,
            warn: _warns.containsKey(t.id),
            onWarn: () {
              _hideSnack();
              _set(() => _markOpen = t.id);
            },
            target: _drag?.over == t.id,
            lifted: _lift?.id == t.id || (_flying[t.id] ?? 0) > _flyNear,
          ),
        ),
      ),
    );
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
