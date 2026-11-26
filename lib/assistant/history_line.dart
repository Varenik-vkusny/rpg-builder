// Набор истории словами вида А (25.11): что сделано (глагол цветом), с чем (имя
// крупно, значок вида), что поменялось («поле было → стало»), откуда (значок
// источника). Раньше заголовок был кашей: «Откат: Правка вручную: Лампа».
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../content/delete_confirm.dart' show objectIcon;
import 'history.dart';
import '../content/quest.dart';
import 'plan_labels.dart';

/// Что сделано набором.
enum Verb { created, changed, deleted, reverted }

/// Откуда набор: форма, жест на холсте, ассистент, справочник.
enum Source { hand, canvas, assistant, import }

/// Значение поля словами (названия вместо ключей).
typedef ShowValue = String? Function(JournalOp op, String key, String? raw);

class HistoryLine {
  const HistoryLine({
    required this.verb,
    required this.name,
    required this.source,
    this.kind,
    this.field,
    this.was,
    this.now,
    this.what,
    this.tally = const {},
    this.off = false,
    this.offWord,
  });

  final Verb verb;

  /// Имя объекта, а у ассистента — его сводка.
  final String name;
  final Source source;

  /// Значок вида объекта (место, враг, предмет…); у ассистента — нет.
  final IconData? kind;

  /// Одно изменённое поле: «атака 3 → 4».
  final String? field;
  final String? was;
  final String? now;

  /// У отката — что откатили: «правка», «создание», «удаление».
  final String? what;

  /// Набор из многих операций: сколько создано, изменено, убрано.
  final Map<Verb, int> tally;

  /// Набор откачен или отклонён — ряд приглушён, плашка со словом.
  final bool off;

  /// «ОТКАЧЕН», «ОТКЛОНЁН» или null.
  final String? offWord;
}

/// Глагол словами — под именем, цветом действия.
String verbWord(Verb v) => switch (v) {
  Verb.created => 'Создано',
  Verb.changed => 'Изменено',
  Verb.deleted => 'Удалено',
  Verb.reverted => 'Откат',
};

IconData verbIcon(Verb v) => switch (v) {
  Verb.created => Symbols.add_rounded,
  Verb.changed => Symbols.edit_rounded,
  Verb.deleted => Symbols.remove_rounded,
  Verb.reverted => Symbols.undo_rounded,
};

IconData sourceIcon(Source s) => switch (s) {
  Source.hand => Symbols.edit_note_rounded,
  Source.canvas => Symbols.touch_app_rounded,
  Source.assistant => Symbols.auto_awesome_rounded,
  Source.import => Symbols.download_rounded,
};

String sourceWord(Source s) => switch (s) {
  Source.hand => 'вручную',
  Source.canvas => 'холст',
  Source.assistant => 'ассистент',
  Source.import => 'Open5e',
};

/// Разбирает набор [s]. [original] — набор, который [s] откатывает.
HistoryLine describe(
  ChangeSetEntry s, {
  required WorldSnapshot world,
  required ShowValue show,
  ChangeSetEntry? original,
}) {
  if (s.revertsId != null) {
    final o = original == null
        ? null
        : describe(original, world: world, show: show);
    return HistoryLine(
      verb: Verb.reverted,
      name: o?.name ?? _plainName(s),
      kind: o?.kind,
      source: o?.source ?? sourceOf(s),
      what: switch (o?.verb) {
        Verb.created => 'создание',
        Verb.deleted => 'удаление',
        _ => 'правка',
      },
      off: s.status != SetStatus.applied,
      offWord: _offWord(s.status),
    );
  }
  final source = sourceOf(s);
  final main = _mainOp(s);
  final verb = _verbOf(s, source);
  final single = s.ops.length == 1 ? s.ops.single : null;
  final change = single != null && single.action == 'update'
      ? single.changes.firstOrNull
      : null;
  final many = source == Source.assistant && s.ops.length > 1;
  return HistoryLine(
    verb: verb,
    name: source == Source.assistant ? _plainName(s) : _nameOf(s, main),
    kind: source == Source.assistant || main == null
        ? null
        : opIcon(main, world),
    source: source,
    field: change == null ? null : fieldWord(change.$1),
    was: change == null ? null : show(single!, change.$1, change.$2),
    now: change == null ? null : show(single!, change.$1, change.$3),
    tally: many
        ? {
            for (final v in [Verb.created, Verb.changed, Verb.deleted])
              if (_count(s, v) case final n when n > 0) v: n,
          }
        : const {},
    off: s.status != SetStatus.applied,
    offWord: _offWord(s.status),
  );
}

String? _offWord(SetStatus s) => switch (s) {
  SetStatus.reverted => 'ОТКАЧЕН',
  SetStatus.rejected => 'ОТКЛОНЁН',
  SetStatus.applied => null,
};

/// Источник — по подписи набора: формы пишут «вручную», жесты — «Холст:».
Source sourceOf(ChangeSetEntry s) {
  final t = s.request;
  if (t.startsWith('Холст:')) return Source.canvas;
  // Формы подписывают набор началом: «Правка / Создано / Удаление вручную:» —
  // слово «вручную» в просьбе ассистенту источник не меняет (ревью 26.11).
  if (RegExp(r'^(Правка|Создано|Удаление) вручную:').hasMatch(t)) {
    return Source.hand;
  }
  if (t.startsWith('Импорт из Open5e') ||
      s.summary.startsWith('Импорт из Open5e')) {
    return Source.import;
  }
  return Source.assistant;
}

String _plainName(ChangeSetEntry s) =>
    s.summary.isEmpty ? s.request : s.summary;

/// Имя объекта: из подписи («Правка вручную: Лампа», «Холст: создано «Враг 1»»),
/// иначе — название главной операции.
String _nameOf(ChangeSetEntry s, JournalOp? main) {
  final t = _plainName(s);
  final quoted = RegExp(r'«([^»]+)»').firstMatch(t);
  if (t.startsWith('Холст:') && quoted != null) return quoted.group(1)!;
  final colon = t.indexOf(': ');
  if (colon > 0 && !t.startsWith('Холст:')) return t.substring(colon + 2);
  if (main != null) return main.title;
  return t.replaceFirst('Холст: ', '');
}

const _objectTypes = {'location', 'item', 'character', 'quest', 'event'};

/// Операция над самим объектом (не строка добычи и не шаг квеста).
JournalOp? _mainOp(ChangeSetEntry s) =>
    s.ops.where((o) => _objectTypes.contains(o.type)).firstOrNull ??
    s.ops.firstOrNull;

Verb _verbOf(ChangeSetEntry s, Source source) {
  final t = s.request;
  if (t.startsWith('Создано вручную') || t.startsWith('Холст: создано')) {
    return Verb.created;
  }
  if (t.startsWith('Удаление вручную')) return Verb.deleted;
  if (source == Source.import) return Verb.created;
  final actions = {for (final o in s.ops) o.action};
  if (actions.length == 1 && actions.single == 'create') return Verb.created;
  if (actions.length == 1 && actions.single == 'delete') return Verb.deleted;
  return Verb.changed;
}

int _count(ChangeSetEntry s, Verb v) => s.ops
    .where(
      (o) => switch (v) {
        Verb.created => o.action == 'create',
        Verb.deleted => o.action == 'delete',
        _ => o.action == 'update',
      },
    )
    .length;

/// Подпись поля строчными — та же, что в формах и плане: «атака», «вид».
String fieldWord(String key) =>
    fieldLabel(key.replaceAll(RegExp(r'_id$'), '')).toLowerCase();

/// Значок объекта операции: по самому объекту, а убранного — по виду строки.
IconData opIcon(JournalOp op, WorldSnapshot world) {
  final id = (op.after?['id'] ?? op.before?['id'])?.toString();
  if (id != null && world.titles.containsKey(id)) return objectIcon(world, id);
  return switch (op.type) {
    'character' => Symbols.person_rounded,
    'item' => Symbols.deployed_code_rounded,
    'quest' => Symbols.flag_rounded,
    'event' => Symbols.bolt_rounded,
    _ => Symbols.landscape_rounded,
  };
}

/// Значение поля словами: ссылки — названиями, вид шага — «поговорить / убить».
ShowValue valueShower(WorldSnapshot world) {
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
