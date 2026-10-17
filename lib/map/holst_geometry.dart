// Холст мира (5е): где что стоит на экране — жетоны уровня и полки, нити к рисованию,
// препятствия для подписей. Нити считаются в координатах экрана холста.
part of 'holst_screen.dart';

extension _Geometry on _HolstState {
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
    RenderObject? box, canvas;
    try {
      box = _shelfKeys[id]?.currentContext?.findRenderObject();
      canvas = _canvasKey.currentContext?.findRenderObject();
    } catch (_) {
      // Жетон полки, ушедший за край, уже снят с дерева — его нет на экране.
      return null;
    }
    if (box is! RenderBox || canvas is! RenderBox || !box.attached) return null;
    final o = canvas.globalToLocal(box.localToGlobal(Offset.zero));
    return (rect: o & box.size, shelf: true);
  }

  /// Нити по требованию: в покое их нет, видны только у выбранного объекта.
  /// Каждая проложена в обход блоков (иначе нить «проходит сквозь» чужой объект).
  List<ThreadSpec> _threads() {
    if (_far) return const [];
    final raw = _rawThreads();
    // Пока холст или блок едут под пальцем — без обхода: он считается, когда встанет.
    if (raw.isEmpty || _moving || _lift != null || _drag != null) return raw;
    final blocks = _blocks();
    // Пути ищутся по очереди: следующая нить обходит полосы прежних. Один и тот же
    // набор путей не ищется дважды, пока холст и нити не поменялись.
    final key = Object.hashAll([
      ...blocks,
      for (final t in raw) ...[t.a, t.b],
    ]);
    final routes = _routes[key] ??= _routeAll(raw, blocks);
    if (_routes.length > 60) _routes.removeWhere((k, _) => k != key);
    return [for (final (i, t) in raw.indexed) t.withRoute(routes[i])];
  }

  List<List<Offset>?> _routeAll(List<ThreadSpec> raw, List<Rect> blocks) {
    final taken = <Offset>{};
    final band = Rect.fromLTWH(
      0,
      _vp.height - HolstShelf.height + 2,
      _vp.width,
      HolstShelf.height,
    );
    return [
      for (final t in raw)
        () {
          final r = routeAround(
            t.a,
            t.b,
            blocks,
            _vp,
            aOnlyTop: t.aShelf,
            bOnlyTop: t.bShelf,
            forbidden: band,
            taken: taken,
          );
          if (r != null) taken.addAll(pathCells(r));
          return r;
        }(),
    ];
  }

  /// Блоки, которые нить обходит: жетоны и двери. Полка закрыта целиком полосой.
  List<Rect> _blocks() {
    final m = _view.value;
    return [
      for (final p in _scene.places) ...[
        for (final t in p.tokens) toScreen(m, t.rect),
        for (final d in p.doors) toScreen(m, d.rect),
      ],
    ];
  }

  List<ThreadSpec> _rawThreads() {
    return [
      ?_pendingThread(),
      // План на холсте: новые нити — зелёные, изменённые — пурпурные, и в покое.
      for (final l in _links)
        if (_planThreads['${l.a}>${l.b}'] case final tone?
            when !(_sel != null && l.touches(_sel!)))
          if ((_rectOf(l.a), _rectOf(l.b)) case (final a?, final b?))
            ThreadSpec(
              a: a.rect,
              b: b.rect,
              aShelf: a.shelf,
              bShelf: b.shelf,
              label: l.label,
              loot: l.loot,
              tone: tone,
            ),
      // Связь последнего жеста — зелёная и в покое.
      for (final l in _links)
        if (_threadMarks.contains('${l.a}>${l.b}') &&
            !(_sel != null && l.touches(_sel!)))
          if ((_rectOf(l.a), _rectOf(l.b)) case (final a?, final b?))
            ThreadSpec(
              a: a.rect,
              b: b.rect,
              aShelf: a.shelf,
              bShelf: b.shelf,
              label: l.label,
              loot: l.loot,
              tone: ThreadTone.isNew,
            ),
    ];
  }

  /// Подпись не ложится на блоки: жетоны, двери и полку целиком.
  /// Связи выбранного — метками на объектах; невидимые — меткой у края; за дверью — на двери.
  HolstTags _tags() {
    final sel = _sel;
    if (_far || sel == null) {
      return (tags: const [], edges: const [], doors: const []);
    }
    final shelfTop = _vp.height - HolstShelf.height;
    final canvasView = Rect.fromLTWH(0, 0, _vp.width, shelfTop);
    final shelfView = Rect.fromLTWH(
      28,
      shelfTop,
      _vp.width - 28,
      HolstShelf.height,
    );
    final shelfIds = [for (final t in _scene.shelf) t.id];
    final seen = [
      for (final (i, id) in shelfIds.indexed)
        if (_rectOf(id) case final r? when shelfView.overlaps(r.rect)) i,
    ];
    final tags = <TagSpec>[], edges = <EdgeSpec>[], doors = <Rect>[];
    for (final g in linkGroups(sel, _links)) {
      final r = _rectOf(g.other);
      final i = shelfIds.indexOf(g.other);
      if (r == null && i >= 0) {
        // Жетон полки не построен — он за краем полки: метка с той стороны.
        final left = seen.isNotEmpty && i < seen.first;
        edges.add((
          id: g.other,
          at: Offset(
            left ? shelfView.left + 8 : shelfView.right - 8,
            shelfView.top + 8,
          ),
        ));
        continue;
      }
      if (r == null) {
        if (_doorWith(g.other) case final d?) doors.add(d);
        continue;
      }
      final view = r.shelf ? shelfView : canvasView;
      if (view.contains(r.rect.center)) {
        tags.add((id: g.other, rect: r.rect, text: g.words.join(', ')));
      } else {
        edges.add((id: g.other, at: edgePoint(view, r.rect)));
      }
    }
    return (tags: tags, edges: edges, doors: doors);
  }

  /// Дверь, за которой (на любой глубине) стоит объект [id]; на экране.
  Rect? _doorWith(String id) {
    final placeId = _scene.all[id]?.placeId ?? id;
    for (final p in _scene.places) {
      for (final d in p.doors) {
        if (placeAndInside(_w.locations, d.place.id).contains(placeId)) {
          return toScreen(_view.value, d.rect);
        }
      }
    }
    return null;
  }

  /// Те же блоки, что обходит нить, и полка целиком.
  List<Rect> _obstacles() {
    return [
      ..._blocks(),
      Rect.fromLTWH(
        0,
        _vp.height - HolstShelf.height,
        _vp.width,
        HolstShelf.height,
      ),
    ];
  }
}
