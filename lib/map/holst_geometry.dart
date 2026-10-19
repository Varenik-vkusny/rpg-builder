// Холст мира (5е): где что стоит на экране — жетоны уровня и полки — и где встают метки
// связей. Всё в координатах экрана холста.
part of 'holst_screen.dart';

extension _Geometry on _HolstState {
  /// Где жетон на экране (в координатах холста): на уровне — из мира, на полке — по ключу.
  /// Объект другого уровня — null: метка встаёт на дверь или не встаёт вовсе.
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

  /// Метки связей. Выбран объект — белые метки на соседях: что сосед в связи («выдаёт»,
  /// «шаг 4: поговорить»). Ничего не выбрано — план «Менять», связь последнего жеста и
  /// связь под колёсиком метят второй конец именем первого: «Слизень роняет 35%».
  /// Невидимый — метка у края, за дверью — на двери. В покое — значки откуда связи.
  HolstTags _tags() {
    if (_far) {
      return (
        tags: const [],
        edges: const [],
        doors: const [],
        badges: const [],
      );
    }
    final sel = _sel;
    final groups = <String, _TagGroup>{};
    if (sel != null) {
      for (final g in linkGroups(sel, _links)) {
        groups[g.other] = (words: g.words, tone: ThreadTone.hot, icon: null);
      }
    }
    final pending = _pendingLink();
    for (final (l, tone) in [
      for (final l in _links)
        if (_planThreads['${l.a}>${l.b}'] ??
                (_threadMarks.contains('${l.a}>${l.b}')
                    ? ThreadTone.isNew
                    : null)
            case final tone?)
          (l, tone),
      if (pending != null) (pending, ThreadTone.isNew),
    ]) {
      if (sel != null) continue;
      final from = _scene.all[l.a];
      final g = groups[l.b] ??= (
        words: [],
        tone: tone,
        icon: from == null ? null : tokenIcon(from),
      );
      final word = l.wordOn(l.a), name = from?.title ?? '';
      g.words.add(
        l.step == null ? '$name $word' : '$name, шаг ${l.step}: $word',
      );
    }
    final placed = _place(groups);
    return (
      tags: placed.tags,
      edges: placed.edges,
      doors: placed.doors,
      // Где уже стоит метка — она и объясняет связь; значки под ней не прячутся.
      badges: sel == null && _plan == null
          ? [
              for (final b in _badges())
                if (!placed.tags.any((x) => x.rect == b.rect)) b,
            ]
          : const [],
    );
  }

  /// Значки в покое: на объекте — откуда его связи (значок второго конца и «35%», «×3»,
  /// номер шага). Не больше трёх, остальное — «+N».
  List<BadgeSpec> _badges() {
    final into = <String, List<HolstLink>>{};
    for (final l in _links) {
      into.putIfAbsent(l.b, () => []).add(l);
    }
    return [
      for (final MapEntry(key: id, value: ls) in into.entries)
        if (_rectOf(id) case final r? when _visible(r))
          (
            rect: r.rect,
            chips: [
              for (final l in ls.take(ls.length > 3 ? 2 : 3))
                if (_scene.all[l.a] case final from?)
                  (icon: tokenIcon(from), text: l.chip),
              if (ls.length > 3) (icon: null, text: '+${ls.length - 2}'),
            ],
          ),
    ];
  }

  /// Жетон на экране целиком в своей области: полка — в полке, холст — над ней.
  bool _visible(({Rect rect, bool shelf}) r) {
    final shelfTop = _vp.height - HolstShelf.height;
    final view = r.shelf
        ? Rect.fromLTWH(28, shelfTop, _vp.width - 28, HolstShelf.height)
        : Rect.fromLTWH(0, 0, _vp.width, shelfTop);
    return view.contains(r.rect.center);
  }

  /// Где встают метки [groups]: на объекте, у края в его сторону или на двери.
  ({List<TagSpec> tags, List<EdgeSpec> edges, List<DoorSpec> doors}) _place(
    Map<String, _TagGroup> groups,
  ) {
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
    final tags = <TagSpec>[], edges = <EdgeSpec>[], doors = <DoorSpec>[];
    for (final MapEntry(key: id, value: g) in groups.entries) {
      final r = _rectOf(id);
      final i = shelfIds.indexOf(id);
      final hidden = r == null
          ? i >= 0
          : r.shelf && !shelfView.contains(r.rect.center);
      if (hidden) {
        // Жетон полки за её краем (не построен или обрезан): стрелка висит на верхнем
        // углу полки с той стороны и смотрит по диагонали вниз, туда (владелец 19.10).
        final left = r == null
            ? seen.isNotEmpty && i < seen.first
            : r.rect.center.dx < shelfView.center.dx;
        edges.add((
          id: id,
          at: Offset(
            left ? shelfView.left + 16 : shelfView.right - 16,
            shelfView.top - 2,
          ),
          dir: Offset(left ? -1 : 1, 1) / math.sqrt2,
          tone: g.tone,
        ));
        continue;
      }
      if (r == null) {
        if (_doorWith(id) case final d?) doors.add((rect: d, tone: g.tone));
        continue;
      }
      final view = r.shelf ? shelfView : canvasView;
      if (view.contains(r.rect.center)) {
        tags.add((
          id: id,
          rect: r.rect,
          text: g.words.join(', '),
          tone: g.tone,
          icon: g.icon,
        ));
      } else {
        final at = edgePoint(view, r.rect);
        edges.add((
          id: id,
          at: at,
          dir: towards(at, r.rect.center),
          tone: g.tone,
        ));
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
}

/// Слова метки одного объекта, её цвет и значок первого конца (у выбранного — без значка).
typedef _TagGroup = ({List<String> words, ThreadTone tone, IconData? icon});
