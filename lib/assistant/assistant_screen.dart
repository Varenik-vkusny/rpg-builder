import 'package:flutter/material.dart';

import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../worlds/world.dart';
import 'assistant_service.dart';
import 'change_set.dart';
import 'assistant_flow.dart';
import 'plan_view.dart';
import 'question_dialog.dart';

/// Ассистент: автор выбирает область и пишет просьбу — получает план.
/// В базу отсюда не пишется ничего.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.world,
    required this.snapshot,
    required this.assistant,
    required this.repo,
    this.initialScope,
    this.initialRequest,
  });

  final World world;
  final WorldSnapshot snapshot;
  final AssistantService assistant;

  /// Куда пишется применённый или отклонённый набор изменений.
  final ContentRepo repo;

  /// Заранее выбранная область и просьба — с экрана «Проверка мира» (3.8).
  final Scope? initialScope;
  final String? initialRequest;

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

  /// Просьба, на которую получен [_run].
  ProposeRequest? _asked;

  @override
  void initState() {
    super.initState();
    if (widget.initialScope case final s?) {
      _type = s.type;
      _slug = s.slug;
    }
    _request.text = widget.initialRequest ?? '';
  }

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
      // Ассистент может сначала спросить автора — ответы копятся и уходят с просьбой.
      var answers = <Answer>[];
      while (true) {
        final asked = ProposeRequest(
          worldId: widget.world.id,
          scope: Scope(_type, _slug!),
          request: text,
          answers: answers,
        );
        try {
          final run = await runAssistant(
            assistant: widget.assistant,
            world: widget.snapshot,
            request: asked,
            onAttempt: (n) {
              if (mounted) setState(() => _attempt = n);
            },
          );
          if (mounted) {
            setState(() {
              _run = run;
              _asked = asked;
            });
          }
          return;
        } on QuestionAsked catch (q) {
          if (!mounted) return;
          final answer = await askAuthor(context, q.question);
          if (answer == null) {
            if (mounted) {
              setState(() => _error = 'Без ответа ассистент план не составит');
            }
            return;
          }
          answers = [...answers, Answer(q.question.question, answer)];
        }
      }
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
      Row(
        spacing: 8,
        children: [
          Expanded(
            child: FilledButton(
              key: const Key('plan-apply'),
              onPressed: _busy || !run.canApply ? null : () => _decide(true),
              child: const Text('Применить'),
            ),
          ),
          Expanded(
            child: OutlinedButton(
              key: const Key('plan-reject'),
              onPressed: _busy ? null : () => _decide(false),
              child: const Text('Отклонить'),
            ),
          ),
        ],
      ),
      if (_error != null) _errorText(),
      const SizedBox(height: 16),
      PlanView(plan: run.proposal.plan, preview: run.preview),
    ];
  }

  Widget _errorText() => Text(
    _error!,
    key: const Key('assistant-error'),
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );

  /// «Применить» — план одной транзакцией; «Отклонить» — только в журнал.
  /// Успех — назад в мир; при применении мир перечитывается.
  Future<void> _decide(bool apply) async {
    final draft = ChangeSetDraft.fromRun(_run!, _asked!);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      apply
          ? await widget.repo.applyChangeSet(widget.world.id, draft)
          : await widget.repo.rejectChangeSet(widget.world.id, draft);
      if (mounted) Navigator.of(context).pop(apply);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apply
              ? 'Не удалось применить — в мире ничего не изменилось: $e'
              : 'Не удалось записать отказ: $e';
        });
      }
    }
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
          if (_error != null && _run == null) _errorText(),
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
