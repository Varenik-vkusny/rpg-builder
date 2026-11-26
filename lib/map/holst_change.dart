// Холст мира (5е), режим «Менять»: фраза → план ассистента тем же путём, что на экране
// ассистента (петля исправлений, вопросы автору, проверка на копии). План до 6 изменений
// проступает на холсте по шагу; больше — список «было → стало» с «показать на холсте».
// Изменения на других уровнях — метка на двери. «Применить» — общей функцией плана фразы.
part of 'holst_screen.dart';

/// План на холсте: прогон ассистента, просьба, строки и сколько уже проступило.
typedef PlanState = ({
  PlanRun run,
  ProposeRequest asked,
  List<PlanRow> rows,
  int shown,
  bool big,
  bool peek,
  bool ready,
});

/// Шаг показа плана по шагу (как в принятом прототипе).
const _planStep = Duration(milliseconds: 620);

extension _Change on _HolstState {
  /// Область фразы: выбранный квест или персонаж — он сам; событие — его место;
  /// иначе — место, нажатое в «Менять», или место, в которое вошли.
  Scope? get _scope {
    final t = _sel == null ? null : _scene.all[_sel];
    if (t != null) {
      switch (t.kind) {
        case TokenKind.quest:
          return Scope(ScopeType.quest, t.slug);
        case TokenKind.enemy || TokenKind.npc:
          return Scope(ScopeType.character, t.slug);
        case TokenKind.event:
          final l = _w.locations.where((x) => x.id == t.placeId).firstOrNull;
          if (l != null) return Scope(ScopeType.location, l.slug);
        case TokenKind.item:
          break;
      }
    }
    final placeId = _scopePlace ?? (_path.isEmpty ? null : _path.last.id);
    final l = _w.locations.where((x) => x.id == placeId).firstOrNull;
    return l == null ? null : Scope(ScopeType.location, l.slug);
  }

  String? get _scopeTitle {
    final s = _scope;
    if (s == null) return null;
    return switch (s.type) {
      ScopeType.location =>
        _w.locations.firstWhere((x) => x.slug == s.slug).title,
      ScopeType.quest => _w.quests.firstWhere((x) => x.slug == s.slug).title,
      ScopeType.character =>
        _w.characters.firstWhere((x) => x.slug == s.slug).title,
    };
  }

  Future<void> _ask() async {
    final scope = _scope, text = _phrase.text.trim();
    if (scope == null || text.isEmpty) return;
    _hideSnack();
    _set(() => _asking = true);
    try {
      var answers = <Answer>[];
      while (true) {
        final asked = ProposeRequest(
          worldId: widget.world.id,
          scope: scope,
          request: text,
          answers: answers,
        );
        try {
          final run = await runAssistant(
            assistant: widget.assistant,
            world: _w,
            request: asked,
          );
          if (!mounted) return;
          await _showPlan(run, asked);
          return;
        } on QuestionAsked catch (q) {
          if (!mounted) return;
          final a = await askAuthor(context, q.question);
          if (a == null) return;
          answers = [...answers, Answer(q.question.question, a)];
        }
      }
    } catch (e) {
      if (mounted) {
        _say(SnackData(title: 'Плана нет', sub: '$e', tone: GestureTone.error));
      }
    } finally {
      if (mounted) _set(() => _asking = false);
    }
  }

  /// До 6 изменений — проступают по шагу; больше — весь план сразу и список.
  Future<void> _showPlan(PlanRun run, ProposeRequest asked) async {
    final plan = run.proposal.plan;
    final rows = planRows(run.preview.ops, run.preview.copy);
    final big = plan.ops.length > planStepsOnCanvas;
    _set(() {
      _sel = null;
      _plan = (
        run: run,
        asked: asked,
        rows: rows,
        shown: big ? rows.length : 0,
        big: big,
        peek: false,
        ready: big,
      );
    });
    _planCells = planCells(
      buildScene(
        run.preview.copy,
        _focus,
        first: {
          for (final m in planMarks(_w, run.preview.copy).entries)
            if (m.value == Mark.isNew) m.key,
        },
        slots: _slots,
      ),
    );
    if (big) return _preview(run.preview.copy);
    for (var k = 1; k <= plan.ops.length; k++) {
      final p = _plan;
      if (p == null || !mounted) return;
      _preview(planPrefix(_w, plan, k));
      // Строки той операции, что сейчас проступила.
      final upTo = planRows(
        run.preview.ops.take(k).toList(),
        run.preview.copy,
      ).length;
      _set(() => _plan = _with(p, shown: upTo, ready: k == plan.ops.length));
      await Future<void>.delayed(_planStep);
    }
  }

  PlanState _with(PlanState p, {int? shown, bool? peek, bool? ready}) => (
    run: p.run,
    asked: p.asked,
    rows: p.rows,
    shown: shown ?? p.shown,
    big: p.big,
    peek: peek ?? p.peek,
    ready: ready ?? p.ready,
  );

  /// Холст показывает копию мира после плана: новое — зелёным, изменённое — пурпуром.
  void _preview(WorldSnapshot copy) => _set(() {
    _copy = copy;
    _marks
      ..clear()
      ..addAll(planMarks(_w, copy));
    _planThreads = planThreads(_w, copy);
    _rebuild();
  });

  /// «Показать на холсте»: список сворачивается, холст едет к объекту строки.
  void _showRow(PlanRow r) {
    final p = _plan;
    if (p == null) return;
    _set(() => _plan = _with(p, peek: true));
    final rect = [
      for (final pl in _scene.places)
        if (pl.place.id == r.target) pl.rect,
      for (final t in _scene.onCanvas)
        if (t.id == r.target) t.rect,
    ].firstOrNull;
    if (rect != null) _flyTo(centerOn(_vp, rect, 1, HolstShelf.height));
  }

  /// «Внутри 3 изменения» на двери: план меняет что-то уровнем ниже.
  String? _doorMark(String doorId) {
    if (_plan == null || _copy == null) return null;
    final n = changesInside(_copy!, doorId, _marks.keys);
    return n == 0 ? null : 'внутри ${changesWord(n)}';
  }

  Future<void> _decidePlan(bool apply) async {
    final p = _plan;
    if (p == null) return;
    _set(() => _busy = true);
    final failed = await decidePlan(
      widget.repo,
      widget.world.id,
      p.run,
      p.asked,
      apply: apply,
    );
    if (!mounted) return;
    if (failed != null) {
      _set(() => _busy = false);
      // Нет связи — план остаётся на холсте, «Повторить» — то же решение (26.11).
      return _say(
        SnackData(
          title: failed.offline ? 'Нет связи' : 'Не записано',
          sub: failed.safeRetry
              ? 'план не потерян'
              : failed.offline
              ? 'связь оборвалась — проверь историю'
              : failed.message,
          tone: GestureTone.error,
          action: failed.safeRetry ? 'Повторить' : null,
          onAction: failed.safeRetry
              ? () {
                  _hideSnack();
                  _decidePlan(apply);
                }
              : null,
          seconds: failed.safeRetry ? 10 : 5,
        ),
      );
    }
    final marks = Map.of(_marks), threads = Map.of(_planThreads);
    _set(() {
      _plan = null;
      _copy = null;
      _planCells = null;
      _planThreads = const {};
      _busy = false;
      _phrase.clear();
    });
    await _reload();
    if (!mounted) return;
    if (!apply) {
      _set(() {
        _marks.clear();
        _rebuild();
      });
      return _say(
        const SnackData(
          title: 'План отклонён',
          kind: DoneKind.rejected,
          sub: null,
          seconds: 2,
        ),
      );
    }
    final setId = (await widget.repo.history(widget.world.id)).first.id;
    _set(() {
      _marks
        ..clear()
        ..addAll(marks);
      _planThreads = threads;
      _rebuild();
    });
    _say(
      SnackData(
        title: 'План применён: ${changesWord(p.run.proposal.plan.ops.length)}',
        kind: DoneKind.applied,
        // Крупное действие — одно короткое напоминание, где его найти (владелец 19.11).
        sub: 'в истории',
        action: 'Откатить',
        onAction: () => _undo(setId, done: 'Набор откачен'),
        seconds: 7,
      ),
    );
  }
}

/// Клетки и ширина мест итога плана — для шагов показа.
({Map<String, Map<String, int>> slots, Set<String> wide}) planCells(
  HolstScene s,
) => (
  slots: {for (final p in s.places) p.place.id: p.cellOf},
  wide: {
    for (final p in s.places)
      if (p.rect.width == wideWidth) p.place.id,
  },
);
