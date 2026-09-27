// Карточка операции плана: что за объект, метка изменения, «было → стало» по каждому полю.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/parts.dart';
import 'plan.dart';
import 'plan_apply.dart';
import 'plan_labels.dart';

/// Значок поля: одна система для плана и страниц объектов.
const fieldIcons = <String, IconData>{
  'Название': Symbols.title_rounded,
  'Описание': Symbols.notes_rounded,
  'Уровни от': Symbols.military_tech_rounded,
  'Уровни до': Symbols.military_tech_rounded,
  'Уровень': Symbols.military_tech_rounded,
  'Вид': Symbols.category_rounded,
  'Редкость': Symbols.diamond_rounded,
  'Урон': Symbols.swords_rounded,
  'Защита': Symbols.shield_rounded,
  'Цена': Symbols.payments_rounded,
  'Роль': Symbols.badge_rounded,
  'Здоровье': Symbols.favorite_rounded,
  'Атака': Symbols.swords_rounded,
  'Локация': Symbols.location_on_rounded,
  'Выдаёт': Symbols.person_rounded,
  'Шанс': Symbols.percent_rounded,
  'Количество': Symbols.tag_rounded,
  'Шаг': Symbols.flag_rounded,
};

IconData opIcon(PlanOp op) => switch (op.type) {
  OpType.location => Symbols.landscape_rounded,
  OpType.item => Symbols.deployed_code_rounded,
  OpType.character when op.str('role') == 'enemy' => Symbols.skull_rounded,
  OpType.character => Symbols.person_rounded,
  OpType.quest || OpType.questStep => Symbols.flag_rounded,
  OpType.loot => Symbols.inventory_2_rounded,
  OpType.questReward => Symbols.redeem_rounded,
};

Change changeOf(OpAction a) => switch (a) {
  OpAction.create => Change.create,
  OpAction.update => Change.update,
  OpAction.delete => Change.delete,
};

class OpCard extends StatelessWidget {
  const OpCard({super.key, required this.result, this.outside});

  final OpResult result;

  /// Что именно в операции вне области; null — всё в области.
  final List<String>? outside;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final (_, type, name) = splitOpTitle(r.title);
    final s = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 14,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: s.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(opIcon(r.op), color: s.onSurfaceVariant),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Row(
                        spacing: 8,
                        children: [
                          ChangeTag(changeOf(r.op.action)),
                          Flexible(
                            child: Text(
                              type,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: s.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (outside case final keys?)
              NoticeBanner(Notice.error, keys.join(', '), title: 'Вне области'),
            if (r.error case final e?)
              NoticeBanner(Notice.error, e, title: 'Не выполнить'),
            for (final fix in r.op.repairs) NoticeBanner(Notice.fix, fix),
            if (r.error == null) ..._changes(r),
          ],
        ),
      ),
    );
  }

  static List<Widget> _changes(OpResult r) {
    if (r.op.action == OpAction.delete && r.changes.isEmpty) {
      return [const Text('Удаляется целиком')];
    }
    return [
      for (final c in r.changes)
        BeforeAfter(
          label: c.label,
          before: c.before,
          after: c.after,
          icon: fieldIcons[c.label.split(' ').first] ?? fieldIcons[c.label],
        ),
    ];
  }
}
