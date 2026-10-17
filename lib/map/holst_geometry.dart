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
    final box = _shelfKeys[id]?.currentContext?.findRenderObject();
    final canvas = _canvasKey.currentContext?.findRenderObject();
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
      if (_sel != null)
        for (final l in _links)
          if (l.touches(_sel!))
            if ((_rectOf(l.a), _rectOf(l.b)) case (final a?, final b?))
              ThreadSpec(
                a: a.rect,
                b: b.rect,
                aShelf: a.shelf,
                bShelf: b.shelf,
                // Слова — глазами выбранного: у Обвала Кирка «в награду».
                label: l.wordFor(_sel),
                loot: l.loot,
                tone: ThreadTone.hot,
              ),
    ];
  }

  /// Подпись не ложится на блоки: жетоны, двери и полку целиком.
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
