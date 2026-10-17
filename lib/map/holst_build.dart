// Холст мира (5е), режим «Строить»: из палитры в место — объект создан. Каждый жест идёт
// одной дорогой (gesture_path.dart): проверка на копии, история, откат; 5 секунд «Отменить».
part of 'holst_screen.dart';

extension _Build on _HolstState {
  /// Место под точкой холста [local] (координаты экрана холста); null — мимо мест.
  HolstPlace? _placeAt(Offset local) {
    final w = toWorld(_view.value, local);
    for (final p in _scene.places.reversed) {
      if (p.rect.contains(w)) return p;
    }
    return null;
  }

  Offset? _local(Offset global) {
    final box = _canvasKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : null;
  }

  void _dragOver(DragTargetDetails<NewKind> d) {
    final l = _local(d.offset);
    final kind = d.data;
    final id = l == null || kind == NewKind.item || kind == NewKind.place
        ? null
        : _placeAt(l)?.place.id;
    if (id != _dropPlace) _set(() => _dropPlace = id);
  }

  Future<void> _drop(DragTargetDetails<NewKind> d) async {
    _set(() => _dropPlace = null);
    final l = _local(d.offset);
    if (l == null || _busy) return;
    final kind = d.data;
    final focus = _path.isEmpty ? null : _path.last;
    final place = _placeAt(l)?.place;
    if ((kind == NewKind.enemy ||
            kind == NewKind.npc ||
            kind == NewKind.event) &&
        place == null) {
      return _say(
        const SnackData(title: 'Брось в место', sub: null, seconds: 2),
      );
    }
    // Новое место — рядом с остальными на этом уровне; внутри места — его уровни.
    final levels = focus == null
        ? (
            widget.world.levelMin,
            math.min(widget.world.levelMin + 2, widget.world.levelMax),
          )
        : (focus.levelMin, focus.levelMax);
    final made = createByGesture(
      widget.world.id,
      _w,
      kind,
      placeId: switch (kind) {
        NewKind.item => null,
        NewKind.place => focus?.id,
        _ => place!.id,
      },
      levels: levels,
    );
    final where = switch (kind) {
      NewKind.item => ' на полке',
      NewKind.place => '',
      _ => ' в «${place!.title}»',
    };
    await _gesture(
      made.edit,
      done: 'Создано: ${newTitle(kind)}$where',
      marks: {made.id: Mark.isNew},
    );
  }

  /// Жест через единственную дорогу; применён — мир перечитан, полоса с «Отменить».
  Future<void> _gesture(
    ManualEdit edit, {
    required String done,
    required Map<String, Mark> marks,
    Set<String> threads = const {},
    String failed = 'Не применено',
  }) async {
    _set(() => _busy = true);
    final r = await applyGesture(widget.repo, widget.world.id, _w, edit);
    if (!mounted) return;
    if (!r.applied) {
      _set(() => _busy = false);
      return _say(
        SnackData(
          title: failed,
          sub: r.reason,
          tone: GestureTone.error,
          action: 'Понятно',
          onAction: _hideSnack,
          seconds: 6,
        ),
      );
    }
    await _reload();
    if (!mounted) return;
    final setId = r.setId;
    _set(() {
      _busy = false;
      _marks
        ..clear()
        ..addAll(marks);
      _threadMarks
        ..clear()
        ..addAll(threads);
      for (final p in r.warnings) {
        if (setId != null) _warns[p.objectId] = (text: p.message, setId: setId);
      }
    });
    _say(
      SnackData(
        title: done,
        tone: r.tone,
        action: setId == null ? null : 'Отменить',
        onAction: setId == null ? null : () => _undo(setId),
      ),
    );
  }

  /// «Отменить» и «Откатить»: тот же откат, что в истории изменений.
  Future<void> _undo(String setId, {String done = 'Отменено'}) async {
    _hideSnack();
    final why = await undoGesture(widget.repo, widget.world.id, setId);
    if (!mounted) return;
    if (why != null) {
      return _say(
        SnackData(
          title: 'Не откачено',
          sub: why,
          tone: GestureTone.error,
          seconds: 4,
        ),
      );
    }
    await _reload();
    if (!mounted) return;
    _set(() {
      _marks.clear();
      _threadMarks.clear();
      _warns.removeWhere((_, w) => w.setId == setId);
    });
    _say(SnackData(title: done, seconds: 2));
  }

  void _say(SnackData s) {
    _snackTimer?.cancel();
    _set(() => _snack = s);
    _snackTimer = Timer(Duration(seconds: s.seconds), _hideSnack);
  }

  void _hideSnack() {
    _snackTimer?.cancel();
    if (mounted && _snack != null) _set(() => _snack = null);
  }
}
