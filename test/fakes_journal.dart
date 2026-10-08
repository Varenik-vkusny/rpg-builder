// Журнал подменённой базы: записи наборов изменений (см. fakes_db.dart).
import 'package:rpg_builder/assistant/change_set.dart';
import 'package:rpg_builder/assistant/history.dart';
import 'package:rpg_builder/check/world_check.dart';

/// Набор в журнале подменённой базы: запись истории, мир до него и номер версии после.
class FakeJournalSet {
  const FakeJournalSet({
    required this.worldId,
    required this.entry,
    required this.before,
    required this.version,
  });

  final String worldId;
  final ChangeSetEntry entry;
  final WorldSnapshot? before;
  final int version;

  FakeJournalSet reverted() => FakeJournalSet(
    worldId: worldId,
    entry: ChangeSetEntry(
      id: entry.id,
      status: SetStatus.reverted,
      request: entry.request,
      summary: entry.summary,
      createdAt: entry.createdAt,
      revertsId: entry.revertsId,
      ops: entry.ops,
    ),
    before: before,
    version: version,
  );
}

/// Записанный набор изменений: статус и что было в нём.
typedef FakeChangeSet = ({String status, ChangeSetDraft draft});
