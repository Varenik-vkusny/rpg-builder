// Холст мира (5е), режим «Строить»: провёл пальцем от объекта к объекту — связь. Вид
// угадан по паре; число — колёсиком на нити; квест → житель — меню «Поговорить / Убить».
// Связь записывается той же дорогой жеста: проверка, история, «Отменить».
part of 'holst_screen.dart';

/// Связь, которую сейчас задают: вид (null — ждёт меню), концы, число и где показать окно.
typedef PendingLink = ({
  LinkKind? kind,
  String from,
  String to,
  int value,
  Offset at,
});

/// Нить под пальцем: откуда тянут, где палец, над каким объектом.
typedef DragThread = ({String from, Offset at, String? over});

extension _Link on _HolstState {
  /// Жетон под точкой холста [p] — на уровне или на полке, кроме [except].
  String? _tokenAt(Offset p, String except) {
    final ids = [
      for (final t in _scene.onCanvas) t.id,
      for (final t in _scene.shelf) t.id,
    ];
    for (final id in ids) {
      if (id == except) continue;
      if (_rectOf(id)?.rect.contains(p) ?? false) return id;
    }
    return null;
  }

  bool get _canThread => _mode == HolstMode.build && !_far && !_busy;

  void _threadStart(String id, DragStartDetails d) {
    final at = _local(d.globalPosition);
    if (!_canThread || at == null) return;
    _hideSnack();
    _set(() {
      _sel = null;
      _link = null;
      _drag = (from: id, at: at, over: null);
    });
  }

  void _threadMove(DragUpdateDetails d) {
    final g = _drag, at = _local(d.globalPosition);
    if (g == null || at == null) return;
    _set(() => _drag = (from: g.from, at: at, over: _tokenAt(at, g.from)));
  }

  Future<void> _threadEnd() async {
    final g = _drag;
    _set(() => _drag = null);
    if (g == null) return;
    final to = g.over;
    if (to == null) {
      return _say(
        const SnackData(
          title: 'Отпусти на другом объекте',
          sub: null,
          seconds: 2,
        ),
      );
    }
    final a = _scene.all[g.from]!, b = _scene.all[to]!;
    final rule = linkRule(a, b);
    if (rule == null) {
      final first = kindName(a.kind);
      return _say(
        SnackData(
          title:
              '${first[0].toUpperCase()}${first.substring(1)} и '
              '${kindName(b.kind)} не связываются',
          sub: null,
          tone: GestureTone.error,
          seconds: 3,
        ),
      );
    }
    final kind = rule.kind;
    if (kind != null && linked(_w, kind, rule.from, rule.to)) {
      return _say(
        SnackData(
          title: 'Уже связаны: ${a.title} и ${b.title}',
          sub: null,
          seconds: 2,
        ),
      );
    }
    final pending = (
      kind: kind,
      from: rule.from,
      to: rule.to,
      value: wheelStart(rule.wheel),
      at: g.at,
    );
    if (rule.menu || rule.wheel != Wheel.none) {
      return _set(() => _link = pending);
    }
    await _linkDone(pending);
  }

  /// Меню «Поговорить / Убить»: убить — ещё колёсико «Сколько».
  void _pickKind(LinkKind k) {
    final p = _link;
    if (p == null) return;
    final next = (kind: k, from: p.from, to: p.to, value: 1, at: p.at);
    if (wheelOf(k) == Wheel.none) {
      _set(() => _link = null);
      _linkDone(next);
    } else {
      _set(() => _link = next);
    }
  }

  void _linkValue(int v) {
    final p = _link;
    if (p == null) return;
    _set(
      () => _link = (kind: p.kind, from: p.from, to: p.to, value: v, at: p.at),
    );
  }

  Future<void> _linkDone(PendingLink p) async {
    _set(() => _link = null);
    final kind = p.kind!;
    final a = _scene.all[p.from]!, b = _scene.all[p.to]!;
    await _gesture(
      linkByGesture(widget.world.id, _w, kind, p.from, p.to, p.value),
      done: 'Связь: ${a.title} — ${linkLabel(kind, p.value)} — ${b.title}',
      marks: const {},
      threads: {'${p.from}>${p.to}'},
    );
  }

  /// Окно колёсика или меню у места, где отпустили нить; не выходит за края холста.
  Widget? _linkPopup() {
    final p = _link;
    if (p == null) return null;
    final a = _scene.all[p.from]!, b = _scene.all[p.to]!;
    final menu = p.kind == null;
    final w = menu ? 200.0 : 150.0, h = menu ? 140.0 : 224.0;
    final left = (p.at.dx - w / 2).clamp(8.0, _vp.width - w - 8);
    final top = (p.at.dy + 16).clamp(
      8.0,
      _vp.height - HolstShelf.height - h - 8,
    );
    return Positioned(
      left: left,
      top: top,
      child: menu
          ? LinkMenu(title: '${a.title} → ${b.title}', onPick: _pickKind)
          : NumberWheel(
              key: ValueKey('${p.from}>${p.to}>${p.kind}'),
              wheel: wheelOf(p.kind!),
              onChanged: _linkValue,
              onDone: () => _linkDone(p),
            ),
    );
  }

  /// Связь, которую задают колёсиком: метка с числом, ещё не в мире.
  HolstLink? _pendingLink() {
    final p = _link;
    if (p == null || p.kind == null) return null;
    return HolstLink(p.from, p.to, linkLabel(p.kind!, p.value));
  }
}
