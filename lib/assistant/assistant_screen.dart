import 'package:flutter/material.dart';

import '../check/world_check.dart';
import '../worlds/world.dart';
import 'assistant_service.dart';
import 'assistant_flow.dart';
import 'plan_view.dart';

/// Ассистент: автор выбирает область и пишет просьбу — получает план.
/// В базу отсюда не пишется ничего.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.world,
    required this.snapshot,
    required this.assistant,
  });

  final World world;
  final WorldSnapshot snapshot;
  final AssistantService assistant;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _request = TextEditingController();
  ScopeType _type = ScopeType.location;
  String? _slug;
  bool _busy = false;
  String? _error;

  /// Номер текущей попытки, пока ассистент думает (1 — план, 2–3 — исправления).
  int _attempt = 0;

  /// Последний план после автоисправлений и его проверка на копии.
  PlanRun? _run;

  @override
  void dispose() {
    _request.dispose();
    super.dispose();
  }

  /// Объекты выбранного вида: slug → название.
  List<(String, String)> get _objects {
    final w = widget.snapshot;
    return switch (_type) {
      ScopeType.location => [for (final l in w.locations) (l.slug, l.title)],
      ScopeType.quest => [for (final q in w.quests) (q.slug, q.title)],
      ScopeType.character => [for (final c in w.characters) (c.slug, c.title)],
    };
  }

  Future<void> _propose() async {
    final text = _request.text.trim();
    final problem = _slug == null
        ? 'Выбери объект области'
        : text.isEmpty
        ? 'Напиши просьбу'
        : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _run = null;
    });
    try {
      final run = await runAssistant(
        assistant: widget.assistant,
        world: widget.snapshot,
        request: ProposeRequest(
          worldId: widget.world.id,
          scope: Scope(_type, _slug!),
          request: text,
        ),
        onAttempt: (n) {
          if (mounted) setState(() => _attempt = n);
        },
      );
      if (mounted) setState(() => _run = run);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Widget> _result(PlanRun run) {
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    return [
      const SizedBox(height: 16),
      if (run.fixes > 0)
        Text(
          'Ассистент исправил план сам: ${run.fixes} из $maxFixes раз',
          key: const Key('plan-fixes'),
        ),
      for (final (i, problems) in run.caught.indexed)
        for (final p in problems)
          Text('Поймано перед исправлением ${i + 1}: $p', style: error),
      if (!run.canApply)
        Text(
          run.fixes == maxFixes
              ? 'Ошибки остались и после $maxFixes исправлений — '
                    '«Применить» недоступно'
              : 'В плане ошибки — «Применить» недоступно',
          key: const Key('plan-blocked'),
          style: error,
        ),
      PlanView(plan: run.proposal.plan, preview: run.preview),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    return Scaffold(
      appBar: AppBar(title: const Text('Ассистент')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Область'),
          Wrap(
            spacing: 8,
            children: [
              for (final t in ScopeType.values)
                ChoiceChip(
                  key: Key('scope-type-${t.name}'),
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() {
                    _type = t;
                    _slug = null;
                  }),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: Key('scope-object-${_type.name}'),
            initialValue: _slug,
            isExpanded: true,
            decoration: InputDecoration(labelText: _type.label),
            items: [
              for (final (slug, title) in _objects)
                DropdownMenuItem(value: slug, child: Text(title)),
            ],
            onChanged: (v) => setState(() => _slug = v),
          ),
          TextField(
            key: const Key('assistant-request'),
            controller: _request,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Просьба',
              hintText: 'Затопи штольню, слизни там жить не могут',
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              key: const Key('assistant-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            key: const Key('assistant-propose'),
            onPressed: _busy ? null : _propose,
            child: Text(switch ((_busy, _attempt)) {
              (false, _) => 'Предложить план',
              (true, <= 1) => 'Ассистент думает…',
              (true, final n) =>
                'Ассистент исправляет план: попытка $n из ${maxFixes + 1}',
            }),
          ),
          if (run != null) ..._result(run),
        ],
      ),
    );
  }
}
