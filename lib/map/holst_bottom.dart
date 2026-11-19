// Холст мира (5е), низ экрана: лист плана, палитра «Строить», фраза «Менять», строка
// выбранного и переключатель режимов. Выше — сам холст (holst_canvas.dart).
part of 'holst_screen.dart';

extension _Bottom on _HolstState {
  List<Widget> _bottom(BuildContext context) {
    final sel = _sel == null ? null : _scene.all[_sel];
    return [
      if (_plan case final p?)
        PlanSheet(
          rows: p.rows,
          total: p.run.proposal.plan.ops.length,
          shown: p.shown,
          ready: p.ready,
          errors: p.run.preview.of(Severity.error).length,
          warnings: p.run.preview.of(Severity.warning).length,
          why: p.run.preview.of(Severity.error).firstOrNull?.message,
          canApply: p.run.canApply,
          big: p.big,
          peek: p.peek,
          busy: _busy,
          onShow: _showRow,
          onUnpeek: () => _set(() => _plan = _with(p, peek: false)),
          onApply: () => _decidePlan(true),
          onReject: () => _decidePlan(false),
        )
      else if (_mode == HolstMode.build)
        const HolstPalette()
      else if (_mode == HolstMode.change)
        ChangeTray(
          controller: _phrase,
          scope: _scopeTitle,
          busy: _asking,
          onAsk: _ask,
        ),
      if (sel != null && !_far && _mode == HolstMode.look)
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: HolstInfo(
            token: sel,
            links: [
              for (final g in linkGroups(sel.id, _links))
                (
                  token: _scene.all[g.other],
                  title:
                      _scene.all[g.other]?.title ?? _placeTitle(g.other) ?? '?',
                  words: g.words,
                ),
            ],
            onPage: _openPage,
            onGlyph: frameOf(sel.kind) == null ? null : _pickGlyph,
          ),
        ),
      if (_plan == null)
        HolstModes(
          mode: _mode,
          onMode: (m) => _set(() {
            _mode = m;
            _sel = null;
            _scopePlace = null;
          }),
        ),
    ];
  }

  /// Списки мира; вернулись — перечитать мир: там могли создать, править и удалять.
  Future<void> _openLists() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => widget.lists!()));
    if (mounted) await _reload();
  }

  /// Страница выбранного объекта; вернулись с правкой — перечитать мир.
  Future<void> _openPage() async {
    final id = _sel;
    if (id == null) return;
    final pages = WorldPages(widget.world, widget.repo, _w);
    final page = switch (_scene.all[id]!.kind) {
      TokenKind.enemy || TokenKind.npc => pages.character(
        _w.characters.firstWhere((c) => c.id == id),
      ),
      TokenKind.event => pages.event(_w.events.firstWhere((e) => e.id == id)),
      TokenKind.item => pages.item(_w.items.firstWhere((i) => i.id == id)),
      TokenKind.quest => pages.quest(_w.quests.firstWhere((q) => q.id == id)),
    };
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true) await _reload();
  }

  Future<void> _reload() async {
    final w = await widget.repo.snapshot(widget.world.id);
    if (!mounted) return;
    _set(() {
      _w = w;
      _changed = true;
      if (_sel != null && !worldTokens(w).containsKey(_sel)) _sel = null;
      _rebuild();
    });
  }

  String? _placeTitle(String? id) =>
      _w.locations.where((l) => l.id == id).firstOrNull?.title;
}
