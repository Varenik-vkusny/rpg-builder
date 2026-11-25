import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import '../check/world_check.dart';
import '../content/content_repo.dart';
import '../content/delete_confirm.dart' show objectIcon;
import '../content/quest.dart';
import '../worlds/world.dart';
import 'history.dart';
import '../ui/messages.dart';
import '../ui/parts.dart';
import '../ui/theme.dart';
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
    final show = _shower(world);
    String field(String k) =>
        fieldLabel(k.replaceAll(RegExp(r'_id$'), '')).toLowerCase();
    String back(JournalOp op) => [
      for (final (k, was, _) in op.changes)
        '${field(k)} → ${show(op, k, was) ?? '—'}',
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
          : SheetSubject(_opIcon(single, world), single.title),
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

  /// Значок объекта операции: по самому объекту, а убранного — по виду строки.
  IconData _opIcon(JournalOp op, WorldSnapshot world) {
    final id = (op.after?['id'] ?? op.before?['id'])?.toString();
    final known = id != null && world.titles.containsKey(id);
    if (known) return objectIcon(world, id);
    return switch (op.type) {
      'character' => Symbols.person_rounded,
      'item' => Symbols.deployed_code_rounded,
      'quest' => Symbols.flag_rounded,
      'event' => Symbols.bolt_rounded,
      _ => Symbols.landscape_rounded,
    };
  }

  /// Значение поля словами: ссылки — названиями, вид шага — «поговорить / убить».
  String? Function(JournalOp, String, String?) _shower(WorldSnapshot world) {
    final labels = PlanLabels(() => world);
    final titles = world.titles;
    return (op, key, raw) {
      if (raw == null) return null;
      if (key.endsWith('_id')) return titles[raw] ?? '?';
      if (op.type == 'quest_step' && key == 'kind') {
        return StepKind.values.byName(raw).label;
      }
      return labels.value(key, num.tryParse(raw) ?? raw);
    };
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
    final show = _shower(world);

    final when =
        '${s.createdAt.day.toString().padLeft(2, '0')}.'
        '${s.createdAt.month.toString().padLeft(2, '0')} '
        '${s.createdAt.hour.toString().padLeft(2, '0')}:'
        '${s.createdAt.minute.toString().padLeft(2, '0')}';
    final title = s.summary.isEmpty ? s.request : s.summary;
    // Под «Откатить» — только то, что говорит больше заголовка (владелец 25.11):
    // просьба автора, если она не и есть заголовок; одна операция «новое/убрано: X»
    // при X в заголовке («Создано вручную: Причал») — повтор, не показываем.
    final single = s.ops.length == 1 ? s.ops.single : null;
    final opsRepeatTitle =
        single != null &&
        single.action != 'update' &&
        single.title.isNotEmpty &&
        title.contains(single.title);
    return ExpansionTile(
      key: Key('history-${s.id}'),
      maintainState: true,
      shape: const RoundedRectangleBorder(),
      leading: _statusIcon(s.status),
      title: Text(title),
      subtitle: Text(
        '${s.status.label} · $when'
        '${s.revertsId == null ? '' : ' · откат набора'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._revertArea(s),
        if (s.request != title) ...[
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
          const SizedBox(height: 8),
        ],
        if (!opsRepeatTitle)
          for (final op in s.ops) _op(op, show),
      ],
    );
  }

  /// Операция набора одной строкой: «новое: Кирка», «убрано: Житель»,
  /// «Слизень: атака 3 → 4» (только изменённые поля).
  Widget _op(JournalOp op, String? Function(JournalOp, String, String?) show) {
    String field(String k) =>
        fieldLabel(k.replaceAll(RegExp(r'_id$'), '')).toLowerCase();
    // Каждое значение короче по отдельности: «стало» видно всегда (ревью 22.11).
    String short(String? v) =>
        v == null ? '—' : (v.length > 32 ? '${v.substring(0, 31)}…' : v);
    final link = journalLinkWord(op.type);
    final what = link == null ? op.title : '$link ${op.title}';
    final text = switch (op.action) {
      'create' => 'новое: $what',
      'delete' => 'убрано: $what',
      _ =>
        '$what: ${[for (final (k, was, now) in op.changes) '${field(k)} ${short(show(op, k, was))} → ${short(show(op, k, now))}'].join(', ')}',
    };
    return Padding(
      key: Key('history-op-${op.label}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text),
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
