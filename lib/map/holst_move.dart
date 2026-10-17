// Холст мира (5е), режим «Строить»: держишь объект — он поднимается и едет за пальцем;
// отпустил в другом месте — перенос той же дорогой жеста. Предупреждение — жёлтая метка
// и «Откатить»; ошибка — блок возвращается в свою клетку, внизу причина. Место можно
// поднять целиком и бросить в другое место или на дверь — оно станет вложенным.
// Перелёт — в координатах мира: сменил место — 0.7 с с белой обводкой поверх всех,
// сдвинулся внутри своего — 0.3 с.
part of 'holst_screen.dart';

/// Поднятый блок: что, где взяли (точка мира) и где он сейчас (прямоугольник мира).
typedef Lift = ({String id, bool place, Offset start, Rect from, Rect at});

const _flyFar = 700, _flyNear = 300;

extension _Move on _HolstState {
  bool get _canLift => _mode == HolstMode.build && !_far && !_busy;

  Offset? _worldAt(Offset global) {
    final l = _local(global);
    return l == null ? null : toWorld(_view.value, l);
  }

  void _liftStart(String id, bool place, Rect from, Offset global) {
    final w = _worldAt(global);
    if (!_canLift || w == null) return;
    HapticFeedback.mediumImpact();
    _hideSnack();
    _set(() {
      _sel = null;
      _drag = null;
      _lift = (id: id, place: place, start: w, from: from, at: from);
    });
  }

  void _liftMove(Offset global) {
    final l = _lift, w = _worldAt(global);
    if (l == null || w == null) return;
    _set(() {
      _lift = (
        id: l.id,
        place: l.place,
        start: l.start,
        from: l.from,
        at: l.from.shift(w - l.start),
      );
      _dropPlace = _liftTarget(w, l);
    });
  }

  /// Куда бросят: дверь — внутрь вложенного места, иначе место под пальцем. Само
  /// поднятое место — не цель, но его двери — цель (так получится «место в себе»).
  String? _liftTarget(Offset w, Lift l) {
    for (final p in _scene.places) {
      for (final d in p.doors) {
        if (d.rect.contains(w)) return d.place.id;
      }
    }
    for (final p in _scene.places.reversed) {
      if (p.place.id != l.id && p.rect.contains(w)) return p.place.id;
    }
    return null;
  }

  Future<void> _liftEnd() async {
    final l = _lift;
    if (l == null) return;
    final to = _dropPlace;
    _set(() => _dropPlace = null);
    final from = l.place
        ? _w.locations.firstWhere((x) => x.id == l.id).parentId
        : _scene.all[l.id]!.placeId;
    if (to == null || to == from) {
      if (to == null) {
        _say(const SnackData(title: 'Брось в место', sub: null, seconds: 2));
      }
      return _land(l.id, _flyNear);
    }
    final title = l.place
        ? _w.locations.firstWhere((x) => x.id == l.id).title
        : _scene.all[l.id]!.title;
    final target = _w.locations.firstWhere((x) => x.id == to);
    final old = _w.locations.where((x) => x.id == from).firstOrNull?.title;
    final door = _scene.places.any((p) => p.doors.any((d) => d.place.id == to));
    final ok = await _gesture(
      l.place
          ? movePlace(widget.world.id, _w, l.id, to)
          : moveObject(widget.world.id, _w, l.id, to),
      done: 'Перенесено: $title → ${target.title}${door ? ' (внутрь)' : ''}',
      failed: 'Не перенесено: $title',
      marks: {l.id: Mark.changed},
      undone: 'Откачено: $title → ${old ?? 'мир'}',
    );
    // Не применено — блок возвращается в свою клетку; применено — летит в новую.
    _land(l.id, ok ? _flyFar : _flyNear);
  }

  /// Отпустить поднятый блок: он доедет до своей клетки за [ms].
  void _land(String id, int ms) {
    _set(() {
      _lift = null;
      _flying[id] = ms;
    });
    Timer(Duration(milliseconds: ms + 50), () {
      if (mounted) _set(() => _flying.remove(id));
    });
  }

  /// Где рисовать жетон [t]: поднятый — под пальцем; в поднятом месте — вместе с ним.
  Rect _shown(HolstToken t) {
    final l = _lift;
    if (l == null) return t.rect;
    if (l.id == t.id) return l.at;
    if (l.place && t.placeId == l.id) {
      return t.rect.shift(l.at.topLeft - l.from.topLeft);
    }
    return t.rect;
  }

  Rect _shownPlace(HolstPlace p) {
    final l = _lift;
    return l != null && l.place && l.id == p.place.id ? l.at : p.rect;
  }

  /// Сдвиг двери и «ещё N» вместе с поднятым местом.
  Rect _shownIn(String placeId, Rect r) {
    final l = _lift;
    return l != null && l.place && l.id == placeId
        ? r.shift(l.at.topLeft - l.from.topLeft)
        : r;
  }

  Duration _flyTime(String id) => _lift?.id == id
      ? Duration.zero
      : Duration(milliseconds: _flying[id] ?? _flyNear);

  /// Окно жёлтой метки: текст предупреждения, «Оставить» и «Откатить».
  Widget? _markSheet() {
    final id = _markOpen;
    final w = id == null ? null : _warns[id];
    if (w == null) return null;
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    return Positioned(
      left: 8,
      right: 8,
      bottom: HolstShelf.height + 8,
      child: Material(
        key: const Key('holst-mark-sheet'),
        color: s.surfaceContainerHigh,
        shape: Border.all(color: c.warn),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.warning_rounded, color: c.warn, fill: 1),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      w.text,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: s.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('holst-mark-keep'),
                        onPressed: () => _set(() => _markOpen = null),
                        child: const Text('Оставить'),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('holst-mark-back'),
                        onPressed: () {
                          _set(() => _markOpen = null);
                          _undo(w.setId, done: w.undone);
                        },
                        icon: const Icon(Symbols.undo_rounded),
                        label: const Text('Откатить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
