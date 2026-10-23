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
import 'ru_names.dart';

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

  /// Словарь русских названий SRD (ru_names.dart) — грузится один раз при открытии.
  late final Future<RuNames> _dict = RuNames.load();

  /// Русские названия образцов: ключ → название. Нет в словаре — оригинал.
  Map<String, String> _ru = const {};

  static final _cyrillic = RegExp('[а-яё]', caseSensitive: false);

  String _title(String key, String name) => _ru[key] ?? name;

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Напиши, что искать: «скелет» или «skeleton»');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _picked = null;
      _creature = null;
    });
    try {
      final dict = await _dict;
      _ru = {...dict.creatures, ...dict.items};
      // Справочник ищет только по-английски: русский запрос — по словарю, в Open5e
      // уходят ключи найденного. В словаре нет — справочник не спрашиваем.
      List<String>? keys;
      if (_cyrillic.hasMatch(q)) keys = dict.match(q, creatures: _enemies);
      if (_enemies) {
        final found = keys != null && keys.isEmpty
            ? <Open5eCreature>[]
            : await widget.api.searchCreatures(q, keys: keys);
        if (mounted) setState(() => _creatures = found);
      } else {
        final found = keys != null && keys.isEmpty
            ? <Open5eItem>[]
            : await widget.api.searchItems(q, keys: keys);
        if (mounted) setState(() => _found = found);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Open5e недоступен: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _pick(Open5eItem o) {
    final plan = importPlan(o, widget.snapshot, title: _ru[o.key]);
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
      if (mounted) {
        closeDone(
          context,
          'Импортировано: ${_title(_picked!.key, _picked!.name)}',
        );
      }
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
    final made = importEnemy(
      widget.world.id,
      widget.snapshot,
      c,
      title: _ru[c.key],
    );
    final failed = await saveManualEdit(
      widget.repo,
      widget.world.id,
      widget.snapshot,
      made.edit,
    );
    if (!mounted) return;
    if (failed == null) {
      closeDone(context, 'Импортировано: ${_title(c.key, c.name)}');
    } else {
      setState(() {
        _busy = false;
        _error = failed;
      });
    }
  }

  List<Widget> _enemyPart(Open5eCreature c) {
    final made = importEnemy(
      widget.world.id,
      widget.snapshot,
      c,
      title: _ru[c.key],
    );
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
      EnemyPreview(c: c, title: _title(c.key, c.name), problems: problems),
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
              labelText: 'Название, можно по-русски',
              hintText: _enemies
                  ? 'скелет, гоблин, wolf'
                  : 'кирка, меч, potion',
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
      enemyTile(c, _title(c.key, c.name), () => setState(() => _creature = c)),
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
        title: Text(_title(o.key, o.name)),
        // Есть перевод — оригинал строкой выше чисел, как у врага.
        subtitle: Text(
          '${_ru.containsKey(o.key) ? '${o.name}\n' : ''}'
          '${kindOf(o).label} · ${rarityOf(o).label} · ${o.document}',
        ),
        isThreeLine: _ru.containsKey(o.key),
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
