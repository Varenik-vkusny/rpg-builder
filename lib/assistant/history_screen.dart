import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../worlds/world.dart';
import 'history.dart';
import 'history_line.dart';
import 'history_tile.dart';
import '../ui/messages.dart';
import '../ui/parts.dart';

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

  /// Раскрытые наборы.
  final _open = <String>{};
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
      final world = (await _data).$2;
      if (!mounted || !await _confirmRevert(set, world)) return;
      await widget.repo.revertChangeSet(widget.world.id, set.id);
      _changed = true;
      if (mounted) showDone(context, 'Набор откачен');
      setState(() {
        _data = _load();
      });
    } catch (e) {
      setState(() => _errors[set.id] = '$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Вид А: что откатываем и что вернётся. Одна операция — объект плашкой и что
  /// с ним станет; несколько — набор плашкой и до трёх строк.
  Future<bool> _confirmRevert(ChangeSetEntry set, WorldSnapshot world) {
    final show = valueShower(world);
    String back(JournalOp op) => [
      for (final (k, was, _) in op.changes)
        '${fieldWord(k)} → ${show(op, k, was) ?? '—'}',
    ].join(', ');
    SheetFact fact(JournalOp op, {required bool named}) {
      final who = named ? '${op.title}: ' : '';
      // Без имени строка начинается с глагола — с заглавной.
      String say(String v) =>
          named ? '$who$v' : v[0].toUpperCase() + v.substring(1);
      return switch (op.action) {
        'create' => SheetFact(Symbols.remove_rounded, say('уберётся')),
        'delete' => SheetFact(Symbols.add_rounded, say('вернётся')),
        _ => SheetFact(
          Symbols.edit_rounded,
          op.changes.isEmpty ? say('вернётся как было') : who,
          changed: op.changes.isEmpty ? null : back(op),
        ),
      };
    }

    final single = set.ops.length == 1 ? set.ops.single : null;
    return confirmAction(
      context,
      title: 'Откатить набор?',
      icon: Symbols.undo_rounded,
      subject: single == null
          ? SheetSubject(
              Symbols.history_rounded,
              set.summary.isEmpty ? set.request : set.summary,
            )
          : SheetSubject(opIcon(single, world), single.title),
      facts: [
        if (single != null)
          fact(single, named: false)
        else ...[
          for (final op in set.ops.take(3)) fact(op, named: true),
          if (set.ops.length > 3)
            SheetFact(
              Symbols.more_horiz_rounded,
              'И ещё ${set.ops.length - 3}',
            ),
        ],
      ],
      action: 'Откатить',
      actionIcon: Symbols.undo_rounded,
    );
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
          final byId = {for (final s in sets) s.id: s};
          final now = DateTime.now();
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              for (final (i, s) in sets.indexed) ...[
                if (i == 0 ||
                    dayTitle(s.createdAt, now) !=
                        dayTitle(sets[i - 1].createdAt, now))
                  _Day(dayTitle(s.createdAt, now), first: i == 0),
                _set(s, world, byId),
              ],
            ],
          );
        },
      ),
    ),
  );

  /// Набор: голова (нажатие раскрывает), под ней «Откатить», просьба автора и
  /// операции ячейками цвета действия.
  Widget _set(
    ChangeSetEntry s,
    WorldSnapshot world,
    Map<String, ChangeSetEntry> byId,
  ) {
    final show = valueShower(world);
    final line = describe(
      s,
      world: world,
      show: show,
      original: s.revertsId == null ? null : byId[s.revertsId],
    );
    final colors = Theme.of(context).colorScheme;
    final open = _open.contains(s.id);
    // Под «Откатить» — только то, что говорит больше головы (владелец 25.11):
    // одна операция над тем же объектом, что в голове, — повтор, не показываем.
    final single = s.ops.length == 1 ? s.ops.single : null;
    final opsRepeatHead =
        single != null &&
        single.title.isNotEmpty &&
        (single.action != 'update' || line.field != null) &&
        line.name.contains(single.title);
    return Container(
      key: Key('history-${s.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(
          color: open ? colors.outline : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('history-head-${s.id}'),
            onTap: () =>
                setState(() => open ? _open.remove(s.id) : _open.add(s.id)),
            child: Semantics(
              expanded: open,
              child: HistoryHead(line, s.createdAt),
            ),
          ),
          if (open)
            SetBody(
              top: _revertArea(s),
              request: line.source == Source.assistant && s.request != line.name
                  ? s.request
                  : null,
              ops: opsRepeatHead ? const [] : s.ops,
              show: show,
            ),
        ],
      ),
    );
  }

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
    if (s.canRevert)
      FilledButton.tonalIcon(
        key: Key('revert-${s.id}'),
        icon: const Icon(Symbols.undo_rounded),
        label: const Text('Откатить'),
        onPressed: _busy == null ? () => _revert(s) : null,
      ),
    const SizedBox(height: 12),
  ];
}

/// Заголовок дня: «Сегодня», «Вчера», «22 ноября».
class _Day extends StatelessWidget {
  const _Day(this.title, {required this.first});
  final String title;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(4, first ? 4 : 18, 4, 8),
    child: Text(
      title,
      key: Key('history-day-$title'),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
