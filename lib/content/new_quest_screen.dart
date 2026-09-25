import 'package:flutter/material.dart';

import '../check/world_check.dart';
import '../worlds/world.dart';
import 'character.dart';
import 'content_repo.dart';
import 'item.dart';
import 'location.dart';
import 'manual_edit.dart';
import 'manual_save.dart';
import 'quest.dart';

class NewQuestScreen extends StatefulWidget {
  const NewQuestScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.locations,
    required this.items,
    required this.characters,
    this.editing,
    this.snapshot,
  });

  final World world;
  final ContentRepo repo;
  final List<Location> locations;
  final List<Item> items;
  final List<Character> characters;

  /// Не null — форма правит существующий квест, а не создаёт новый.
  final Quest? editing;

  /// Мир на момент открытия формы — нужен для сохранения правки.
  final WorldSnapshot? snapshot;

  @override
  State<NewQuestScreen> createState() => _NewQuestScreenState();
}

/// Шаг в форме: вид, цель и поле количества.
class _StepRow {
  StepKind kind = StepKind.talk;
  String? targetId;
  final amount = TextEditingController();
}

/// Награда в форме.
class _RewardRow {
  String? itemId;
}

class _NewQuestScreenState extends State<NewQuestScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _giverId;
  final _steps = <_StepRow>[_StepRow()];
  final _rewards = <_RewardRow>[];
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
      final row = _StepRow()
        ..kind = s.kind
        ..targetId = s.targetId;
      if (s.amount != null) row.amount.text = '${s.amount}';
      _steps.add(row);
    }
    for (final id in e.rewardIds) {
      _rewards.add(_RewardRow()..itemId = id);
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

  /// Цели, доступные виду шага: id → название.
  Map<String, String> _targets(StepKind kind) => switch (kind) {
    StepKind.talk => {for (final c in widget.characters) c.id: c.title},
    StepKind.kill => {
      for (final c in widget.characters)
        if (c.role == Role.enemy) c.id: c.title,
    },
    StepKind.collect => {for (final i in widget.items) i.id: i.title},
    StepKind.visit => {for (final l in widget.locations) l.id: l.title},
  };

  /// Шаги из формы или текст ошибки.
  (List<QuestStep>, String?) _readSteps() {
    if (_steps.isEmpty) return (const [], 'Нужен хотя бы один шаг');
    final steps = <QuestStep>[];
    for (final (i, s) in _steps.indexed) {
      if (s.targetId == null) {
        return (const [], 'У шага ${i + 1} не выбрана цель');
      }
      int? amount;
      if (s.kind.counted) {
        amount = int.tryParse(s.amount.text.trim());
        if (amount == null || amount < 1) {
          return (const [], 'Количество в шаге ${i + 1} — целое число от 1');
        }
      }
      steps.add(QuestStep(kind: s.kind, targetId: s.targetId!, amount: amount));
    }
    return (steps, null);
  }

  String? _rewardsError() {
    final ids = [for (final r in _rewards) r.itemId];
    if (ids.contains(null)) return 'Выбери предмет награды';
    if (ids.toSet().length != ids.length) return 'Одна награда дважды';
    return null;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final (steps, stepsError) = _readSteps();
    final problem = title.isEmpty
        ? 'Нужно название квеста'
        : _giverId == null
        ? 'Выбери, кто выдаёт квест'
        : stepsError ?? _rewardsError();
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
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
      return;
    }
    try {
      await widget.repo.createQuest(widget.world.id, now);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось сохранить: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final e = widget.editing!;
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
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Widget _stepRow(int i) {
    final s = _steps[i];
    final targets = _targets(s.kind);
    // Ключ строки — сам шаг: после удаления соседа поля не путаются.
    return Row(
      key: ObjectKey(s),
      children: [
        Text('${i + 1}.'),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<StepKind>(
            key: Key('step-kind-$i'),
            isExpanded: true,
            initialValue: s.kind,
            items: [
              for (final k in StepKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (k) => setState(() {
              s.kind = k!;
              s.targetId = null;
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          // Новый ключ на смену вида: список целей другой, выбор сброшен.
          child: DropdownButtonFormField<String>(
            key: Key('step-target-$i-${s.kind.name}'),
            isExpanded: true,
            initialValue: s.targetId,
            hint: const Text('Цель'),
            items: [
              for (final t in targets.entries)
                DropdownMenuItem(value: t.key, child: Text(t.value)),
            ],
            onChanged: (v) => setState(() => s.targetId = v),
          ),
        ),
        if (s.kind.counted) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: TextField(
              key: Key('step-amount-$i'),
              controller: s.amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Сколько'),
            ),
          ),
        ],
        IconButton(
          tooltip: 'Убрать шаг',
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _steps.removeAt(i).amount.dispose()),
        ),
      ],
    );
  }

  Widget _rewardRow(int i) => Row(
    key: ObjectKey(_rewards[i]),
    children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          key: Key('reward-$i'),
          isExpanded: true,
          initialValue: _rewards[i].itemId,
          hint: const Text('Предмет'),
          items: [
            for (final it in widget.items)
              DropdownMenuItem(value: it.id, child: Text(it.title)),
          ],
          onChanged: (v) => setState(() => _rewards[i].itemId = v),
        ),
      ),
      IconButton(
        tooltip: 'Убрать награду',
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => _rewards.removeAt(i)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Изменить квест' : 'Новый квест'),
        actions: [
          if (_editing)
            IconButton(
              key: const Key('object-delete'),
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
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
          ),
          TextField(
            key: const Key('quest-description'),
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          DropdownButtonFormField<String>(
            key: const Key('quest-giver'),
            initialValue: _giverId,
            decoration: const InputDecoration(labelText: 'Выдаёт'),
            items: [
              for (final g in _givers)
                DropdownMenuItem(value: g.id, child: Text(g.title)),
            ],
            onChanged: (v) => setState(() => _giverId = v),
          ),
          if (_givers.isEmpty)
            const Text('Квест выдаёт только житель — сначала создай жителя'),
          const SizedBox(height: 16),
          const Text('Шаги по порядку'),
          for (var i = 0; i < _steps.length; i++) _stepRow(i),
          TextButton.icon(
            key: const Key('step-add'),
            onPressed: () => setState(() => _steps.add(_StepRow())),
            icon: const Icon(Icons.add),
            label: const Text('Добавить шаг'),
          ),
          const SizedBox(height: 16),
          const Text('Награды'),
          for (var i = 0; i < _rewards.length; i++) _rewardRow(i),
          if (widget.items.isNotEmpty)
            TextButton.icon(
              key: const Key('reward-add'),
              onPressed: () => setState(() => _rewards.add(_RewardRow())),
              icon: const Icon(Icons.add),
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
