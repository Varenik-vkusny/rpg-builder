// Холст мира (5е) — места уровня с объектами внутри, полка у края, нити выбранного.
// Сдвиг и масштаб пальцами; издалека места с числами, вблизи — объекты; дверь ведёт
// уровнем ниже. Формы и страницы объектов остаются запасным путём («Страница»).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../assistant/assistant_flow.dart';
import '../assistant/assistant_service.dart';
import '../assistant/plan_decide.dart';
import '../assistant/question_dialog.dart';
import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../content/event_pages.dart';
import '../content/location.dart';
import '../content/manual_edit.dart';
import '../content/nesting.dart';
import '../content/world_pages.dart';
import '../help/help.dart';
import '../ui/theme.dart';
import '../worlds/world.dart';
import 'gesture_create.dart';
import 'gesture_link.dart';
import 'gesture_move.dart';
import 'gesture_path.dart';
import 'holst_bars.dart';
import 'holst_doors.dart';
import 'holst_help.dart';
import 'holst_links.dart';
import 'holst_modes.dart';
import 'holst_pops.dart';
import 'holst_parts.dart';
import 'holst_plan.dart';
import 'holst_plan_sheet.dart';
import 'holst_scene.dart';
import 'holst_snack.dart';
import 'holst_threads.dart';
import 'holst_view.dart';
import 'map_parts.dart' show DotGrid;

part 'holst_build.dart';
part 'holst_canvas.dart';
part 'holst_change.dart';
part 'holst_geometry.dart';
part 'holst_link.dart';
part 'holst_move.dart';

class HolstScreen extends StatefulWidget {
  const HolstScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.snapshot,
    required this.assistant,
    this.lists,
  });

  final World world;
  final ContentRepo repo;
  final WorldSnapshot snapshot;

  /// Ассистент фразы — режим «Менять».
  final AssistantService assistant;

  /// Экран списков мира — кнопка «Списки» (холст — главный экран мира); null — кнопки нет.
  final Widget Function()? lists;

  @override
  State<HolstScreen> createState() => _HolstState();
}

class _HolstState extends State<HolstScreen>
    with SingleTickerProviderStateMixin {
  late WorldSnapshot _w = widget.snapshot;

  /// Мир меняли со страниц объектов — экран мира перечитает его.
  bool _changed = false;

  /// Места, в которые вошли: пусто — верхний уровень.
  List<Location> _path = const [];
  String? _sel;
  bool _far = false;
  HolstMode _mode = HolstMode.look;

  /// Жест в пути — второй не начинается.
  bool _busy = false;

  /// Место, над которым держат объект из палитры.
  String? _dropPlace;

  /// Полоса после жеста и её таймер.
  SnackData? _snack;
  Timer? _snackTimer;

  /// «Менять»: фраза, ассистент думает, нажатое место-область, план и копия мира после него.
  final _phrase = TextEditingController();
  bool _asking = false;
  String? _scopePlace;
  PlanState? _plan;
  WorldSnapshot? _copy;
  Map<String, ThreadTone> _planThreads = const {};

  /// Подсветка после жеста: новое — зелёным, изменённое — пурпуром (до следующего жеста).
  final _marks = <String, Mark>{};

  /// Связи, проведённые последним жестом: их нити видны и в покое (зелёные).
  final _threadMarks = <String>{};

  /// Нить под пальцем и связь, которую задают колёсиком или меню.
  DragThread? _drag;
  PendingLink? _link;

  /// Подсказку первого входа уже видели (до чтения — не показывать).
  bool _coachSeen = true;

  /// Жёлтые метки: объект с новым предупреждением — текст и набор, который откатить.
  final _warns = <String, ({String text, String setId, String undone})>{};

  /// Открыто окно жёлтой метки этого объекта.
  String? _markOpen;

  /// Поднятый блок и блоки в перелёте (сколько миллисекунд летят).
  Lift? _lift;
  final _flying = <String, int>{};

  final _view = TransformationController();
  late final _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );
  Animation<Matrix4>? _flight;
  Size _vp = Size.zero;
  bool _framed = false;

  /// Кадр и точка между пальцами в начале жеста.
  Matrix4? _start;
  Offset _focal0 = Offset.zero;

  final _canvasKey = GlobalKey();
  final _shelfKeys = <String, GlobalKey>{};
  final _shelfScroll = ScrollController();

  // Сцена, нити и проблемы — пересчитываются при смене мира или уровня.
  late HolstScene _scene;
  late List<HolstLink> _links;
  late List<Problem> _problems;

  @override
  void initState() {
    super.initState();
    _rebuild();
    _fly.addListener(() {
      if (_flight case final f?) _view.value = f.value;
    });
    _view.addListener(_onView);
    coachSeen().then((seen) {
      if (mounted && !seen) setState(() => _coachSeen = false);
    });
  }

  void _coachDone() {
    setState(() => _coachSeen = true);
    markCoachSeen();
  }

  @override
  void dispose() {
    _snackTimer?.cancel();
    _phrase.dispose();
    _fly.dispose();
    _view.dispose();
    _shelfScroll.dispose();
    super.dispose();
  }

  void _rebuild() {
    // Место берём из свежего снимка: его могли переименовать на странице.
    final focus = _path.isEmpty
        ? null
        : _w.locations.where((l) => l.id == _path.last.id).firstOrNull;
    // Пока на холсте план — рисуется копия мира после него.
    final w = _copy ?? _w;
    _scene = buildScene(w, focus);
    _links = worldLinks(w);
    _problems = checkWorld(w);
  }

  void _onView() {
    final far = scaleOf(_view.value) < farScale;
    if (far != _far) {
      setState(() {
        _far = far;
        if (far) _sel = null;
      });
    }
  }

  void _flyTo(Matrix4 end) {
    _flight = Matrix4Tween(
      begin: _view.value,
      end: end,
    ).animate(CurvedAnimation(parent: _fly, curve: Curves.easeOutCubic));
    _fly.forward(from: 0);
  }

  void _toggleZoom() => _flyTo(
    _far
        ? nearView(_vp, _scene.bounds)
        : farView(_vp, _scene.bounds, HolstShelf.height),
  );

  void _go(List<Location> path) => setState(() {
    _path = path;
    _sel = null;
    _framed = false;
    _rebuild();
  });

  void _back() {
    if (_path.isNotEmpty) return _go(_path.sublist(0, _path.length - 1));
    Navigator.of(context).pop(_changed);
  }

  void _tapToken(String id) => setState(() => _sel = _sel == id ? null : id);
  void _setSel(String? id) => setState(() => _sel = id);

  /// setState для частей экрана (holst_build.dart, holst_canvas.dart).
  void _set(VoidCallback f) => setState(f);

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
    setState(() {
      _w = w;
      _changed = true;
      if (_sel != null && !worldTokens(w).containsKey(_sel)) _sel = null;
      _rebuild();
    });
  }

  String get _crumb =>
      _path.isEmpty ? 'Мир' : _path.map((l) => l.title).join(' › ');

  @override
  Widget build(BuildContext context) {
    final sel = _sel == null ? null : _scene.all[_sel];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  HolstTopBar(
                    world: widget.world.title,
                    path: _crumb,
                    far: _far,
                    onBack: _back,
                    onZoom: _scene.places.isEmpty ? null : _toggleZoom,
                    trailing: [
                      if (widget.lists != null)
                        IconButton(
                          key: const Key('holst-lists'),
                          tooltip: 'Списки',
                          icon: const Icon(Symbols.list_alt_rounded),
                          onPressed: _openLists,
                        ),
                      const HelpAction('holst', body: holstLegend),
                    ],
                  ),
                  Expanded(child: _canvas(context)),
                  if (_plan case final p?)
                    PlanSheet(
                      rows: p.rows,
                      total: p.run.proposal.plan.ops.length,
                      shown: p.shown,
                      ready: p.ready,
                      errors: p.run.preview.of(Severity.error).length,
                      warnings: p.run.preview.of(Severity.warning).length,
                      canApply: p.run.canApply,
                      big: p.big,
                      peek: p.peek,
                      busy: _busy,
                      onShow: _showRow,
                      onUnpeek: () =>
                          setState(() => _plan = _with(p, peek: false)),
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
                        where: _placeTitle(sel.placeId),
                        links: linksLine(
                          sel.id,
                          _links,
                          (id) =>
                              _scene.all[id]?.title ?? _placeTitle(id) ?? '?',
                        ),
                        onPage: _openPage,
                      ),
                    ),
                  if (_plan == null)
                    HolstModes(
                      mode: _mode,
                      onMode: (m) => setState(() {
                        _mode = m;
                        _sel = null;
                        _scopePlace = null;
                      }),
                    ),
                ],
              ),
              if (!_coachSeen) HolstCoach(onDone: _coachDone),
            ],
          ),
        ),
      ),
    );
  }

  String? _placeTitle(String? id) =>
      _w.locations.where((l) => l.id == id).firstOrNull?.title;
}
