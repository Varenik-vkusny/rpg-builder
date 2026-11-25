// Холст мира (5е) — места уровня с объектами внутри, полка у края, метки связей.
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
import '../open5e/open5e_api.dart';
import '../open5e/open5e_screen.dart';
import '../ui/action_sheet.dart';
import '../ui/theme.dart';
import '../worlds/world.dart';
import 'gesture_create.dart';
import 'gesture_icon.dart';
import 'gesture_link.dart';
import 'gesture_move.dart';
import 'gesture_path.dart';
import 'holst_bars.dart';
import 'glyph_picker.dart';
import 'glyphs.dart';
import 'holst_doors.dart';
import 'holst_help.dart';
import 'holst_legend.dart';
import 'holst_links.dart';
import 'holst_modes.dart';
import 'holst_pops.dart';
import 'holst_parts.dart';
import 'holst_plan.dart';
import 'holst_plan_sheet.dart';
import 'holst_scene.dart';
import 'holst_snack.dart';
import 'holst_tags.dart';
import 'holst_threads.dart';
import 'holst_view.dart';
import 'token_frame.dart';
import 'map_parts.dart' show DotGrid;
import 'plan_why.dart';

part 'holst_bottom.dart';
part 'holst_build.dart';
part 'holst_canvas.dart';
part 'holst_change.dart';
part 'holst_geometry.dart';
part 'holst_glyph.dart';
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
    this.open5e = const HttpOpen5e(),
  });

  final World world;
  final ContentRepo repo;
  final WorldSnapshot snapshot;

  /// Ассистент фразы — режим «Менять».
  final AssistantService assistant;

  /// Экран списков мира — кнопка «Списки» (холст — главный экран мира); null — кнопки нет.
  final Widget Function()? lists;

  /// Справочник Open5e — третий старт пустого мира.
  final Open5eApi open5e;

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

  /// Откуда пришли: «назад» возвращает на тот уровень, с которого вошли в дверь, а не
  /// на каждого предка по очереди. Иначе из «Копи › Штольня 3» назад вело на «Копи» —
  /// он выглядит как верх мира, если место верхнего уровня одно (владелец 18.11).
  final _trail = <List<Location>>[];
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

  /// Клетки итога плана: шаги плана ставят новые жетоны сразу туда.
  ({Map<String, Map<String, int>> slots, Set<String> wide})? _planCells;
  Map<String, ThreadTone> _planThreads = const {};

  /// Подсветка после жеста: новое — зелёным, изменённое — пурпуром (до следующего жеста).
  final _marks = <String, Mark>{};

  /// Связи, проведённые последним жестом: их метки видны и в покое (зелёные).
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

  // Сцена, связи и проблемы — пересчитываются при смене мира или уровня.
  late HolstScene _scene;

  /// Где стоял каждый жетон места (место → жетон → клетка): после «Применить» план
  /// не двигает старые, новые встают в свободные клетки.
  final _slots = <String, Map<String, int>>{};
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

  // Место берём из свежего снимка: его могли переименовать на странице.
  Location? get _focus => _path.isEmpty
      ? null
      : _w.locations.where((l) => l.id == _path.last.id).firstOrNull;

  void _rebuild() {
    final focus = _focus;
    // Пока на холсте план — рисуется копия мира после него.
    final w = _copy ?? _w;
    // Шаги плана — сразу в итоговых клетках (владелец 21.11: новые не сдвигаются).
    final cells = _copy == null ? null : _planCells;
    // Только что созданное не прячется в «ещё N». Выбранное и предупреждения сюда
    // не идут: копятся и двигали бы соседей (ревью 19.11).
    _scene = buildScene(
      w,
      focus,
      first: {
        for (final m in _marks.entries)
          if (m.value == Mark.isNew) m.key,
      },
      slots: cells == null ? _slots : {..._slots, ...cells.slots},
      widePlaces: cells?.wide ?? const {},
    );
    // Помним клетки только настоящего мира: копия плана — черновик.
    if (_copy == null) {
      for (final p in _scene.places) {
        _slots[p.place.id] = p.cellOf;
      }
    }
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

  /// Вошёл в дверь: путь до места целиком, а «назад» вернёт сюда.
  void _enter(List<Location> path) {
    _trail.add(_path);
    _go(path);
  }

  void _back() {
    if (_trail.isNotEmpty) return _go(_trail.removeLast());
    Navigator.of(context).pop(_changed);
  }

  void _tapToken(String id) => setState(() => _sel = _sel == id ? null : id);
  void _setSel(String? id) => setState(() => _sel = id);

  /// setState для частей экрана (holst_build.dart, holst_canvas.dart).
  void _set(VoidCallback f) => setState(f);

  /// Наверху — имя мира, внутри — путь от места верхнего уровня (владелец 18.11:
  /// слово «Мир» над единственным местом «Копи» путало, где ты).
  String get _crumb => _path.isEmpty
      ? widget.world.title
      : _path.map((l) => l.title).join(' › ');

  @override
  Widget build(BuildContext context) {
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
                    world: _path.isEmpty ? null : widget.world.title,
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
                  ..._bottom(context),
                ],
              ),
              if (!_coachSeen) HolstCoach(onDone: _coachDone),
            ],
          ),
        ),
      ),
    );
  }
}
