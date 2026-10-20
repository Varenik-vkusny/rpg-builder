// Библиотека Open5e (4.6): поиск образца → план «создать предмет» → проверка на копии →
// «Импортировать» одним набором изменений (в историю, с откатом). Враги (5д) — правкой
// вручную с той же проверкой на копии (open5e_enemy.dart).
import 'package:flutter/material.dart';

import '../help/help.dart';
import '../assistant/change_set.dart';
import '../assistant/plan.dart';
import '../assistant/plan_preview.dart';
import '../assistant/plan_view.dart';
import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../content/manual_save.dart';
import '../ui/messages.dart';
import '../ui/parts.dart';
import '../worlds/world.dart';
import 'open5e_api.dart';
import 'open5e_enemy.dart';
import 'open5e_enemy_view.dart';
import 'open5e_import.dart';

class Open5eScreen extends StatefulWidget {
  const Open5eScreen({
    super.key,
    required this.world,
    required this.snapshot,
    required this.repo,
    required this.api,
  });

  final World world;
  final WorldSnapshot snapshot;
  final ContentRepo repo;
  final Open5eApi api;

  @override
  State<Open5eScreen> createState() => _Open5eScreenState();
}

class _Open5eScreenState extends State<Open5eScreen> {
  final _query = TextEditingController();
  List<Open5eItem>? _found;

  /// Ищем врагов, а не предметы.
  bool _enemies = false;
  List<Open5eCreature>? _creatures;
  Open5eCreature? _creature;
  Open5eItem? _picked;
  Plan? _plan;
  PlanPreview? _preview;
  bool _busy = false;
  String? _error;

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Напиши, что искать, — название по-английски');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _picked = null;
      _creature = null;
    });
    try {
      if (_enemies) {
        final found = await widget.api.searchCreatures(q);
        if (mounted) setState(() => _creatures = found);
      } else {
        final found = await widget.api.searchItems(q);
        if (mounted) setState(() => _found = found);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Open5e недоступен: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pick(Open5eItem o) {
    final plan = importPlan(o, widget.snapshot);
    setState(() {
      _picked = o;
      _plan = plan;
      _preview = previewPlan(widget.snapshot, plan, null);
    });
  }

  Future<void> _import() async {
    final plan = _plan!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repo.applyChangeSet(
        widget.world.id,
        ChangeSetDraft.imported(
          request: plan.summary,
          plan: plan,
          slug: plan.ops.single.slug!,
        ),
      );
      if (mounted) closeDone(context, 'Импортировано: ${_picked!.name}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось импортировать — в мире ничего не изменилось: $e';
        });
      }
    }
  }

  Future<void> _importEnemy() async {
    final c = _creature!;
    setState(() {
      _busy = true;
      _error = null;
    });
    final made = importEnemy(widget.world.id, widget.snapshot, c);
    final failed = await saveManualEdit(
      widget.repo,
      widget.world.id,
      widget.snapshot,
      made.edit,
    );
    if (!mounted) return;
    if (failed == null) {
      closeDone(context, 'Импортировано: ${c.name}');
    } else {
      setState(() {
        _busy = false;
        _error = failed;
      });
    }
  }

  List<Widget> _enemyPart(Open5eCreature c) {
    final made = importEnemy(widget.world.id, widget.snapshot, c);
    final problems = newProblems(
      widget.snapshot,
      made.edit.applyTo(widget.snapshot),
    );
    final broken = problems.any((p) => p.severity == Severity.error);
    return [
      const SizedBox(height: 16),
      Text(
        'Источник: Open5e, ${c.document}. Враг запомнит источник и карточку '
        'оригинала — они уйдут и в экспорт.',
        key: const Key('open5e-attribution'),
      ),
      const SizedBox(height: 12),
      EnemyPreview(c: c, problems: problems),
      const SizedBox(height: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          FilledButton(
            key: const Key('open5e-import'),
            onPressed: _busy || broken ? null : _importEnemy,
            child: const Text('Импортировать'),
          ),
          OutlinedButton(
            key: const Key('open5e-back'),
            onPressed: _busy ? null : () => setState(() => _creature = null),
            child: const Text('К поиску'),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Образцы Open5e'),
        actions: const [HelpAction('open5e')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            key: const Key('open5e-kind'),
            segments: const [
              ButtonSegment(value: false, label: Text('Предметы')),
              ButtonSegment(value: true, label: Text('Враги')),
            ],
            selected: {_enemies},
            onSelectionChanged: _busy
                ? null
                : (v) => setState(() {
                    _enemies = v.single;
                    _picked = null;
                    _creature = null;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('open5e-query'),
            controller: _query,
            decoration: InputDecoration(
              labelText: 'Название по-английски',
              hintText: _enemies
                  ? 'skeleton, goblin, wolf'
                  : 'pick, sword, potion',
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('open5e-search'),
            onPressed: _busy ? null : _search,
            child: Text(
              _busy && _picked == null && _creature == null ? 'Ищу…' : 'Найти',
            ),
          ),
          if (_error != null)
            Text(_error!, key: const Key('open5e-error'), style: error),
          if (_enemies && _creature != null)
            ..._enemyPart(_creature!)
          else if (_enemies)
            ..._enemyResults()
          else if (_picked != null)
            ..._importPart(_picked!)
          else
            ..._results(),
        ],
      ),
    );
  }

  List<Widget> _enemyResults() => [
    if (_creatures != null && _creatures!.isEmpty)
      const ListTile(
        key: Key('open5e-empty'),
        subtitle: Text('Ничего не нашлось'),
      ),
    for (final c in _creatures ?? const <Open5eCreature>[])
      enemyTile(c, () => setState(() => _creature = c)),
  ];

  List<Widget> _results() => [
    if (_found != null && _found!.isEmpty)
      const ListTile(
        key: Key('open5e-empty'),
        subtitle: Text('Ничего не нашлось'),
      ),
    for (final o in _found ?? const <Open5eItem>[])
      ListTile(
        key: Key('open5e-${o.key}'),
        title: Text(o.name),
        subtitle: Text(
          '${kindOf(o).label} · ${rarityOf(o).label} · ${o.document}',
        ),
        onTap: () => _pick(o),
      ),
  ];

  List<Widget> _importPart(Open5eItem o) {
    final preview = _preview!;
    return [
      const SizedBox(height: 16),
      Text(
        'Источник: Open5e, ${o.document} — CC BY 4.0. '
        'Предмет запомнит источник, он уйдёт и в экспорт.',
        key: const Key('open5e-attribution'),
      ),
      // Ошибка — плашкой со значком и словом, не одним красным цветом (инвариант 27.09).
      if (preview.hasErrors)
        const NoticeBanner(
          Notice.error,
          'В плане ошибки — «Импортировать» недоступно',
        ),
      // Друг под другом: в ряд «Импортировать» не влезало при крупном шрифте.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          FilledButton(
            key: const Key('open5e-import'),
            onPressed: _busy || preview.hasErrors ? null : _import,
            child: const Text('Импортировать'),
          ),
          OutlinedButton(
            key: const Key('open5e-back'),
            onPressed: _busy ? null : () => setState(() => _picked = null),
            child: const Text('К поиску'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      PlanView(plan: _plan!, preview: preview),
    ];
  }
}
