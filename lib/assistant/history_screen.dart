import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../content/quest.dart';
import '../worlds/world.dart';
import 'history.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
import 'plan_cards.dart';
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
      setState(() {
        _data = _load();
      });
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
      appBar: AppBar(
        title: const Text('История изменений'),
        actions: const [HelpAction('history')],
      ),
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final s in sets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(child: _set(s, world)),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _set(ChangeSetEntry s, WorldSnapshot world) {
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
      maintainState: true,
      shape: const RoundedRectangleBorder(),
      leading: _statusIcon(s.status),
      title: Text(s.summary.isEmpty ? s.request : s.summary),
      subtitle: Text(
        '${s.status.label} · $when'
        '${s.revertsId == null ? '' : ' · откат набора'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            Icon(
              Symbols.chat_bubble_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            Expanded(child: Text('«${s.request}»')),
          ],
        ),
        const SizedBox(height: 12),
        for (final op in s.ops) ..._op(op, show),
        ..._revertArea(s),
      ],
    );
  }

  /// Операция набора: метка, заголовок, «было → стало» по каждому полю.
  List<Widget> _op(
    JournalOp op,
    String? Function(JournalOp, String, String?) show,
  ) => [
    Row(
      spacing: 8,
      children: [
        ChangeTag(_change(op.action)),
        Expanded(
          child: Text(
            journalOpTitle(op.action, op.type, '«${op.title}»'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    for (final (k, was, now) in op.changes)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: BeforeAfter(
          icon: fieldIcons[fieldLabel(k.replaceAll(RegExp(r'_id$'), ''))],
          label: fieldLabel(k.replaceAll(RegExp(r'_id$'), '')),
          before: show(op, k, was),
          after: show(op, k, now),
        ),
      ),
    const SizedBox(height: 8),
  ];

  /// Конфликты и ошибка отката, кнопка «Откатить».
  List<Widget> _revertArea(ChangeSetEntry s) => [
    if (_conflicts[s.id] case final conflicts?)
      NoticeBanner(
        Notice.error,
        [for (final c in conflicts) c.message].join('\n'),
        key: Key('revert-conflicts-${s.id}'),
        title: 'Откат невозможен — объекты меняли после набора',
      ),
    if (_errors[s.id] case final e?)
      NoticeBanner(
        Notice.error,
        e.toString(),
        key: Key('revert-error-${s.id}'),
        title: 'Не удалось откатить — в мире ничего не изменилось',
      ),
    if (s.canRevert) ...[
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        key: Key('revert-${s.id}'),
        icon: const Icon(Symbols.undo_rounded),
        label: const Text('Откатить'),
        onPressed: _busy == null ? () => _revert(s) : null,
      ),
    ],
  ];

  static Change _change(String action) => switch (action) {
    'create' => Change.create,
    'delete' => Change.delete,
    _ => Change.update,
  };

  Widget _statusIcon(SetStatus status) {
    final s = Theme.of(context).colorScheme;
    final (icon, bg, fg) = switch (status) {
      SetStatus.applied => (
        Symbols.check_rounded,
        AppColors.of(context).okContainer,
        AppColors.of(context).onOkContainer,
      ),
      SetStatus.rejected => (
        Symbols.close_rounded,
        s.surfaceContainerHighest,
        s.onSurfaceVariant,
      ),
      SetStatus.reverted => (
        Symbols.undo_rounded,
        s.tertiaryContainer,
        s.onTertiaryContainer,
      ),
    };
    return CircleAvatar(
      backgroundColor: bg,
      child: Icon(icon, color: fg),
    );
  }
}
