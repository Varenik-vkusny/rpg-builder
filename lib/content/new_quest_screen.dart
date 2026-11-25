import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import '../check/world_check.dart';
import '../worlds/world.dart';
import 'character.dart';
import 'content_repo.dart';
import 'form_kit.dart';
import 'event.dart';
import 'item.dart';
import 'location.dart';
import 'manual_edit.dart';
import 'manual_create.dart';
import 'manual_save.dart';
import 'quest.dart';
import 'quest_form_parts.dart';
import '../ui/discard_guard.dart';

class NewQuestScreen extends StatefulWidget {
  const NewQuestScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.locations,
    required this.items,
    required this.characters,
    this.events = const [],
    this.editing,
    this.snapshot,
  });

  final World world;
  final ContentRepo repo;
  final List<Location> locations;
  final List<Item> items;
  final List<Character> characters;
  final List<Event> events;

  /// Не null — форма правит существующий квест, а не создаёт новый.
  final Quest? editing;

  /// Мир на момент открытия формы — нужен для сохранения правки.
  final WorldSnapshot? snapshot;

  @override
  State<NewQuestScreen> createState() => _NewQuestScreenState();
}

class _NewQuestScreenState extends State<NewQuestScreen>
    with DiscardGuard<NewQuestScreen> {
  @override
  List<Object?> get formValues => [
    _title,
    _description,
    _giverId,
    for (final s in _steps) ...[s.kind, s.targetId, s.amount],
    for (final r in _rewards) r.itemId,
  ];

  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _giverId;
  final _steps = <QuestStepRow>[QuestStepRow()];
  final _rewards = <QuestRewardRow>[];
  bool _busy = false;
  String? _error;

  /// Выдаёт квест только житель.
  late final _givers = [
    for (final c in widget.characters)
      if (c.role == Role.npc) c,
  ];

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) return;
    _title.text = e.title;
    _description.text = e.description;
    _giverId = e.giverId;
    for (final s in _steps) {
      s.amount.dispose();
    }
    _steps.clear();
    for (final s in e.steps) {
      final row = QuestStepRow()
        ..kind = s.kind
        ..targetId = s.targetId;
      if (s.amount != null) row.amount.text = '${s.amount}';
      _steps.add(row);
    }
    for (final id in e.rewardIds) {
      _rewards.add(QuestRewardRow()..itemId = id);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final s in _steps) {
      s.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final (steps, stepsError) = readQuestSteps(_steps);
    final problem =
        titleError(title, 'Нужно название квеста') ??
        (_giverId == null
            ? 'Выбери, кто выдаёт квест'
            : stepsError ?? questRewardsError(_rewards));
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final now = NewQuest(
      title: title,
      description: _description.text.trim(),
      giverId: _giverId!,
      steps: steps,
      rewardIds: [for (final r in _rewards) r.itemId!],
    );
    if (_editing) {
      final error = await saveManualEdit(
        widget.repo,
        widget.world.id,
        widget.snapshot!,
        editQuest(widget.world.id, widget.editing!, now),
      );
      if (!mounted) return;
      if (error == null) {
        closeDone(context, 'Сохранено: $title');
      } else {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
      return;
    }
    final error = await createManually(
      widget.repo,
      widget.world.id,
      (w) => createQuestEdit(widget.world.id, w, now),
    );
    if (!mounted) return;
    if (error == null) {
      closeDone(context, 'Создано: $title');
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Future<void> _delete() async {
    final e = widget.editing!;
    if (!await confirmDelete(context, widget.snapshot!, e.id, e.title)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final error = await deleteManually(
      widget.repo,
      widget.world.id,
      widget.snapshot!,
      type: 'quest',
      id: e.id,
      slug: e.slug,
      title: e.title,
    );
    if (!mounted) return;
    if (error == null) {
      closeDone(context, 'Удалено: ${e.title}');
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => guardPop(_form(context));

  Widget _form(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Изменить квест' : 'Новый квест'),
        actions: [
          if (_editing)
            IconButton(
              key: const Key('object-delete'),
              tooltip: 'Удалить',
              icon: const Icon(Symbols.delete_rounded),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('quest-title'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ).help('quest.title'),
          TextField(
            key: const Key('quest-description'),
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Описание'),
          ).help('quest.description'),
          DropdownButtonFormField<String>(
            key: const Key('quest-giver'),
            isExpanded: true,
            initialValue: _giverId,
            decoration: const InputDecoration(labelText: 'Выдаёт'),
            items: [
              for (final g in _givers)
                DropdownMenuItem(value: g.id, child: Text(g.title)),
            ],
            onChanged: (v) => setState(() => _giverId = v),
          ).help('quest.giver'),
          if (_givers.isEmpty)
            const Text('Квест выдаёт только житель — сначала создай жителя'),
          const SizedBox(height: 16),
          const Text('Шаги по порядку'),
          for (var i = 0; i < _steps.length; i++)
            questStepRow(
              i,
              _steps[i],
              questTargets(
                _steps[i].kind,
                characters: widget.characters,
                items: widget.items,
                locations: widget.locations,
                events: widget.events,
              ),
              update: setState,
              onRemove: () =>
                  setState(() => _steps.removeAt(i).amount.dispose()),
            ),
          TextButton.icon(
            key: const Key('step-add'),
            onPressed: () => setState(() => _steps.add(QuestStepRow())),
            icon: const Icon(Symbols.add_rounded),
            label: const Text('Добавить шаг'),
          ),
          const SizedBox(height: 16),
          const Text('Награды'),
          for (var i = 0; i < _rewards.length; i++)
            questRewardRow(
              _rewards[i],
              i,
              widget.items,
              update: setState,
              onRemove: () => setState(() => _rewards.removeAt(i)),
            ),
          if (widget.items.isNotEmpty)
            TextButton.icon(
              key: const Key('reward-add'),
              onPressed: () => setState(() => _rewards.add(QuestRewardRow())),
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Добавить награду'),
            ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('quest-save'),
            onPressed: _busy ? null : _save,
            child: Text(_editing ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }
}
