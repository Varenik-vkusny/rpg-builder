import 'package:flutter/material.dart';

import '../check/world_check.dart';
import '../worlds/world.dart';
import 'assistant_service.dart';
import 'plan.dart';
import 'scope.dart';

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
  Proposal? _proposal;

  /// Операции плана вне области — второй замок после серверной функции.
  Map<int, List<String>> _outside = const {};

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
      _proposal = null;
    });
    try {
      final p = await widget.assistant.propose(
        ProposeRequest(
          worldId: widget.world.id,
          scope: Scope(_type, _slug!),
          request: text,
        ),
      );
      final scope = scopeOf(widget.snapshot, Scope(_type, _slug!));
      if (mounted) {
        setState(() {
          _proposal = p;
          _outside = outOfScope(p.plan, scope);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _proposal;
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
            child: Text(_busy ? 'Ассистент думает…' : 'Предложить план'),
          ),
          if (p != null) ..._planLines(p.plan),
        ],
      ),
    );
  }

  List<Widget> _planLines(Plan plan) => [
    const SizedBox(height: 16),
    Text(
      plan.summary,
      key: const Key('plan-summary'),
      style: Theme.of(context).textTheme.titleMedium,
    ),
    if (_outside.isNotEmpty)
      Text(
        'Операций вне области: ${_outside.length} — такой план применить нельзя',
        key: const Key('plan-out-of-scope'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    for (final (i, op) in plan.ops.indexed)
      ListTile(
        dense: true,
        title: Text(describeOp(op)),
        subtitle: _outside[i] == null
            ? null
            : Text(
                'Вне области: ${_outside[i]!.join(', ')}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
      ),
  ];
}

const _actionLabels = {
  OpAction.create: 'создать',
  OpAction.update: 'изменить',
  OpAction.delete: 'удалить',
};

/// «изменить location shtolnya_3: description = затоплена по пояс».
String describeOp(PlanOp op) {
  final who = switch (op.type) {
    OpType.loot => '${op.character} → ${op.item}',
    OpType.questStep => '${op.quest} шаг ${op.position}',
    OpType.questReward => '${op.quest} → ${op.item}',
    _ => op.slug ?? '?',
  };
  final fields = op.fields.entries.map((e) => '${e.key} = ${e.value}');
  return '${_actionLabels[op.action]} ${op.typeName} $who'
      '${fields.isEmpty ? '' : ': ${fields.join(', ')}'}';
}
