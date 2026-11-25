// Вопрос перед удалением объекта из формы правки — шторка вида А: что удаляем, что
// уйдёт вместе, «откат — в истории». На объект ссылаются — вместо вопроса отказ
// той же структуры: связи строками со значками (раньше — красная строка в форме).
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../check/world_check.dart';
import '../ui/messages.dart';
import 'references.dart';
import 'world_pages.dart' show characterIcon, itemIcon;

/// true — удалять. Если на объект ссылаются — окно отказа и false: удаление всё
/// равно было бы отклонено, спрашивать о невозможном незачем.
Future<bool> confirmDelete(
  BuildContext context,
  WorldSnapshot world,
  String id,
  String title,
) async {
  final subject = SheetSubject(objectIcon(world, id), title);
  final refs = refsTo(world, id);
  if (refs.isNotEmpty) {
    await showRefusal(
      context,
      title: 'Нельзя удалить',
      icon: Symbols.block_rounded,
      subject: subject,
      facts: [
        for (final r in refs) SheetFact(refIcon(r.kind), _capital(r.text)),
      ],
    );
    return false;
  }
  return confirmAction(
    context,
    title: 'Удалить?',
    icon: Symbols.delete_rounded,
    kind: SheetKind.soft,
    subject: subject,
    facts: [
      ..._goesAlong(world, id),
      const SheetFact(Symbols.undo_rounded, 'Откат — в истории'),
    ],
    action: 'Удалить',
    actionIcon: Symbols.delete_rounded,
  );
}

/// Что видно рядом с удаляемым: откуда он и что уходит вместе с ним.
List<SheetFact> _goesAlong(WorldSnapshot w, String id) {
  String? place(String? placeId) => [
    for (final l in w.locations)
      if (l.id == placeId) l.title,
  ].firstOrNull;
  for (final c in w.characters.where((c) => c.id == id)) {
    final items = {for (final i in w.items) i.id: i.title};
    return [
      if (place(c.locationId) case final p?)
        SheetFact(Symbols.landscape_rounded, 'Из «$p»'),
      if (c.loot.isNotEmpty)
        SheetFact(
          Symbols.key_rounded,
          'Добыча: ${[for (final l in c.loot) items[l.itemId] ?? '?'].join(', ')}',
        ),
    ];
  }
  for (final e in w.events.where((e) => e.id == id)) {
    return [
      if (place(e.locationId) case final p?)
        SheetFact(Symbols.landscape_rounded, 'В «$p»'),
    ];
  }
  for (final q in w.quests.where((q) => q.id == id)) {
    return [
      if (q.steps.isNotEmpty)
        SheetFact(Symbols.flag_rounded, 'Шагов: ${q.steps.length}'),
    ];
  }
  for (final l in w.locations.where((l) => l.id == id)) {
    return [
      if (place(l.parentId) case final p?)
        SheetFact(Symbols.landscape_rounded, 'Внутри «$p»'),
    ];
  }
  return const [];
}

/// Значок объекта по его виду — тот же, что в списках мира.
IconData objectIcon(WorldSnapshot w, String id) {
  for (final c in w.characters) {
    if (c.id == id) return characterIcon(c);
  }
  for (final i in w.items) {
    if (i.id == id) return itemIcon(i);
  }
  if (w.quests.any((q) => q.id == id)) return Symbols.flag_rounded;
  if (w.events.any((e) => e.id == id)) return Symbols.bolt_rounded;
  return Symbols.landscape_rounded;
}

/// Значок ссылки в окне отказа.
IconData refIcon(RefKind k) => switch (k) {
  RefKind.nested => Symbols.landscape_rounded,
  RefKind.lives => Symbols.person_rounded,
  RefKind.drops => Symbols.skull_rounded,
  RefKind.gives || RefKind.step || RefKind.reward => Symbols.flag_rounded,
  RefKind.event => Symbols.bolt_rounded,
};

String _capital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
