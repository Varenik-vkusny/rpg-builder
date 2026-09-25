import 'package:flutter/material.dart';

import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../content/quest.dart';
import '../worlds/world.dart';
import 'history.dart';
import 'plan_labels.dart';

/// История наборов изменений мира (3.7): что меняли, «было → стало», откат любого
/// применённого. Объект меняли после набора — конфликт на экране, откат не идёт.
/// Закрывается с true, если мир менялся (откатывали).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.world, required this.repo});

  final World world;
  final ContentRepo repo;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<(List<ChangeSetEntry>, WorldSnapshot)> _data = _load();
  bool _changed = false;
  String? _busy;

  /// Набор → что мешает его откатить (показано после нажатия «Откатить»).
  final _conflicts = <String, List<RevertConflict>>{};
  final _errors = <String, String>{};

  Future<(List<ChangeSetEntry>, WorldSnapshot)> _load() => (
    widget.repo.history(widget.world.id),
    widget.repo.snapshot(widget.world.id),
  ).wait;

  Future<void> _revert(ChangeSetEntry set) async {
    setState(() {
      _busy = set.id;
      _conflicts.remove(set.id);
      _errors.remove(set.id);
    });
    try {
      final conflicts = await widget.repo.revertConflicts(
        widget.world.id,
        set.id,
      );
      if (conflicts.isNotEmpty) {
        setState(() => _conflicts[set.id] = conflicts);
        return;
      }
      await widget.repo.revertChangeSet(widget.world.id, set.id);
      _changed = true;
      setState(() => _data = _load());
    } catch (e) {
      setState(() => _errors[set.id] = '$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(_changed);
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('История изменений')),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('Не удалось загрузить историю: ${snap.error}'),
            );
          }
          final (sets, world) = snap.data!;
          if (sets.isEmpty) {
            return const Center(
              key: Key('history-empty'),
              child: Text('Изменений пока не было'),
            );
          }
          return ListView(children: [for (final s in sets) _set(s, world)]);
        },
      ),
    ),
  );

  Widget _set(ChangeSetEntry s, WorldSnapshot world) {
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    final labels = PlanLabels(() => world);
    final titles = world.titles;
    String? show(JournalOp op, String key, String? raw) {
      if (raw == null) return null;
      if (key.endsWith('_id')) return titles[raw] ?? '?';
      // У шага «вид» — поговорить / убить, а не вид предмета.
      if (op.type == 'quest_step' && key == 'kind') {
        return StepKind.values.byName(raw).label;
      }
      return labels.value(key, num.tryParse(raw) ?? raw);
    }

    final when =
        '${s.createdAt.day.toString().padLeft(2, '0')}.'
        '${s.createdAt.month.toString().padLeft(2, '0')} '
        '${s.createdAt.hour.toString().padLeft(2, '0')}:'
        '${s.createdAt.minute.toString().padLeft(2, '0')}';
    return ExpansionTile(
      key: Key('history-${s.id}'),
      title: Text(s.summary.isEmpty ? s.request : s.summary),
      subtitle: Text(
        '${s.status.label} · $when · «${s.request}»'
        '${s.revertsId == null ? '' : ' · откат набора'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final op in s.ops) ...[
          Text(
            journalOpTitle(op.action, op.type, '«${op.title}»'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final (k, was, now) in op.changes)
            Text(
              '${fieldLabel(k.replaceAll(RegExp(r'_id$'), ''))}: '
              '${show(op, k, was) ?? 'пусто'} → ${show(op, k, now) ?? 'удалено'}',
            ),
          const SizedBox(height: 6),
        ],
        if (_conflicts[s.id] case final conflicts?) ...[
          Text(
            'Откат невозможен — объекты меняли после набора:',
            key: Key('revert-conflicts-${s.id}'),
            style: error,
          ),
          for (final c in conflicts) Text(c.message, style: error),
        ],
        if (_errors[s.id] case final e?)
          Text(
            'Не удалось откатить — в мире ничего не изменилось: $e',
            key: Key('revert-error-${s.id}'),
            style: error,
          ),
        if (s.canRevert)
          OutlinedButton.icon(
            key: Key('revert-${s.id}'),
            icon: const Icon(Icons.undo),
            label: const Text('Откатить'),
            onPressed: _busy == null ? () => _revert(s) : null,
          ),
      ],
    );
  }
}
