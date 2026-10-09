// История наборов изменений (3.7): что меняли, чем кончилось, можно ли откатить.
// Чистый Dart — те же записи читает экран и подменённая база в тестах.

enum SetStatus {
  applied('Применён'),
  rejected('Отклонён'),
  reverted('Откачен');

  const SetStatus(this.label);
  final String label;
}

/// Одна операция набора в журнале: строки до и после (null — не было / не стало).
class JournalOp {
  const JournalOp({
    required this.action,
    required this.type,
    required this.label,
    this.before,
    this.after,
  });

  factory JournalOp.fromRow(Map<String, dynamic> r) => JournalOp(
    action: r['action'] as String,
    type: r['object_type'] as String,
    label: r['object_slug'] as String,
    before: r['before'] as Map<String, dynamic>?,
    after: r['after'] as Map<String, dynamic>?,
  );

  final String action;
  final String type;
  final String label;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  /// Название объекта, если в строке оно есть, иначе подпись («slizen/klyuch»).
  String get title => (after?['title'] ?? before?['title'] ?? label).toString();

  /// Поля, которые операция поменяла: «было → стало». Служебные поля не показываем.
  List<(String, String?, String?)> get changes {
    final keys = {...?before?.keys, ...?after?.keys}..removeAll(_hidden);
    return [
      for (final k in keys)
        if (before?[k] != after?[k])
          (k, before?[k]?.toString(), after?[k]?.toString()),
    ];
  }

  static const _hidden = {'id', 'project_id', 'created_at', 'slug'};
}

class ChangeSetEntry {
  const ChangeSetEntry({
    required this.id,
    required this.status,
    required this.request,
    required this.summary,
    required this.createdAt,
    this.revertsId,
    this.ops = const [],
  });

  factory ChangeSetEntry.fromRow(Map<String, dynamic> r) => ChangeSetEntry(
    id: r['id'] as String,
    status: SetStatus.values.byName(r['status'] as String),
    request: r['request'] as String,
    summary: r['summary'] as String,
    // База отдаёт время по Гринвичу; автору показываем часы его телефона.
    createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
    revertsId: r['reverts_id'] as String?,
    ops: [
      for (final o
          in ((r['change_ops'] as List?) ?? [])..sort(
            (a, b) => (a['position'] as int).compareTo(b['position'] as int),
          ))
        JournalOp.fromRow(o as Map<String, dynamic>),
    ],
  );

  final String id;
  final SetStatus status;
  final String request;
  final String summary;
  final DateTime createdAt;

  /// Этот набор — откат набора с таким id.
  final String? revertsId;
  final List<JournalOp> ops;

  /// Откатить можно только применённый набор (отклонённый мир не менял).
  bool get canRevert => status == SetStatus.applied;
}

/// Объект, который меняли после набора: откат его затрёт — поэтому не идёт.
class RevertConflict {
  const RevertConflict(this.type, this.label, this.reason);

  factory RevertConflict.fromRow(Map<String, dynamic> r) => RevertConflict(
    r['object_type'] as String,
    r['object_slug'] as String,
    r['reason'] as String,
  );

  final String type;
  final String label;
  final String reason;

  String get message => '$label — $reason';
}
