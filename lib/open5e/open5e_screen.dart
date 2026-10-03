// Библиотека Open5e (4.6): поиск образца → план «создать предмет» → проверка на копии →
// «Импортировать» одним набором изменений (в историю, с откатом).
import 'package:flutter/material.dart';

import '../help/help.dart';
import '../assistant/change_set.dart';
import '../assistant/plan.dart';
import '../assistant/plan_preview.dart';
import '../assistant/plan_view.dart';
import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../ui/parts.dart';
import '../worlds/world.dart';
import 'open5e_api.dart';
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
  Open5eItem? _picked;
  Plan? _plan;
  PlanPreview? _preview;
  bool _busy = false;
  String? _error;

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _picked = null;
    });
    try {
      final found = await widget.api.searchItems(q);
      if (mounted) setState(() => _found = found);
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
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось импортировать — в мире ничего не изменилось: $e';
        });
      }
    }
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
          TextField(
            key: const Key('open5e-query'),
            controller: _query,
            decoration: const InputDecoration(
              labelText: 'Название по-английски',
              hintText: 'pick, sword, potion',
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('open5e-search'),
            onPressed: _busy ? null : _search,
            child: Text(_busy && _picked == null ? 'Ищу…' : 'Найти'),
          ),
          if (_error != null)
            Text(_error!, key: const Key('open5e-error'), style: error),
          if (_picked != null) ..._importPart(_picked!) else ..._results(),
        ],
      ),
    );
  }

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
