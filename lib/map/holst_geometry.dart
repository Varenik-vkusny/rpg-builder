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
  List<ThreadSpec> _threads() {
    if (_far) return const [];
    return [
      ?_pendingThread(),
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
}
