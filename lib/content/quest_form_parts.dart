import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help.dart';
import 'character.dart';
import 'event.dart';
import 'item.dart';
import 'location.dart';
import 'quest.dart';

/// Шаг в форме: вид, цель и поле количества.
class QuestStepRow {
  StepKind kind = StepKind.talk;
  String? targetId;
  final amount = TextEditingController();
}

/// Награда в форме.
class QuestRewardRow {
  String? itemId;
}

/// Цели, доступные виду шага: id → название.
Map<String, String> questTargets(
  StepKind kind, {
  required List<Character> characters,
  required List<Item> items,
  required List<Location> locations,
  required List<Event> events,
}) => switch (kind) {
  StepKind.talk => {for (final c in characters) c.id: c.title},
  StepKind.kill => {
    for (final c in characters)
      if (c.role == Role.enemy) c.id: c.title,
  },
  StepKind.collect => {for (final i in items) i.id: i.title},
  StepKind.visit => {for (final l in locations) l.id: l.title},
  StepKind.event => {for (final e in events) e.id: e.title},
};

/// Шаги из формы или текст ошибки.
(List<QuestStep>, String?) readQuestSteps(List<QuestStepRow> rows) {
  if (rows.isEmpty) return (const [], 'Нужен хотя бы один шаг');
  final steps = <QuestStep>[];
  for (final (i, s) in rows.indexed) {
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

String? questRewardsError(List<QuestRewardRow> rewards) {
  final ids = [for (final r in rewards) r.itemId];
  if (ids.contains(null)) return 'Выбери предмет награды';
  if (ids.toSet().length != ids.length) return 'Одна награда дважды';
  return null;
}

/// Строка шага; [update] — setState формы, [onRemove] убирает шаг.
Widget questStepRow(
  int i,
  QuestStepRow s,
  Map<String, String> targets, {
  required void Function(VoidCallback) update,
  required VoidCallback onRemove,
}) {
  // Ключ строки — сам шаг: после удаления соседа поля не путаются.
  // Две строки: «номер · вид · убрать», под ней «цель · сколько» — на телефоне ничего не режется.
  return Column(
    key: ObjectKey(s),
    children: [
      Row(
        children: [
          Text('${i + 1}.'),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<StepKind>(
              key: Key('step-kind-$i'),
              isExpanded: true,
              initialValue: s.kind,
              items: [
                for (final k in StepKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) => update(() {
                s.kind = k!;
                s.targetId = null;
              }),
            ).help('quest.step.kind'),
          ),
          IconButton(
            tooltip: 'Убрать шаг',
            icon: const Icon(Symbols.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
      Row(
        children: [
          const SizedBox(width: 24),
          Expanded(
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
              onChanged: (v) => update(() => s.targetId = v),
            ).help('quest.step.target'),
          ),
          if (s.kind.counted) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: TextField(
                key: Key('step-amount-$i'),
                controller: s.amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Сколько'),
              ).help('quest.step.amount'),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
    ],
  );
}

/// Строка награды.
Widget questRewardRow(
  QuestRewardRow reward,
  int i,
  List<Item> items, {
  required void Function(VoidCallback) update,
  required VoidCallback onRemove,
}) => Row(
  key: ObjectKey(reward),
  children: [
    Expanded(
      child: DropdownButtonFormField<String>(
        key: Key('reward-$i'),
        isExpanded: true,
        initialValue: reward.itemId,
        hint: const Text('Предмет'),
        items: [
          for (final it in items)
            DropdownMenuItem(value: it.id, child: Text(it.title)),
        ],
        onChanged: (v) => update(() => reward.itemId = v),
      ).help('quest.reward'),
    ),
    IconButton(
      tooltip: 'Убрать награду',
      icon: const Icon(Symbols.close_rounded),
      onPressed: onRemove,
    ),
  ],
);
