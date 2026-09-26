// Образец Open5e → план «создать предмет» (4.6). Импорт идёт тем же путём, что план ассистента:
// проверка на копии, «было → стало», apply_change_set — в историю, с откатом.
import '../assistant/plan.dart';
import '../check/world_check.dart';
import '../content/item.dart';
import '../content/slug.dart';
import 'open5e_api.dart';

/// Подпись источника у предмета и в экспорте.
const open5eSource = 'Open5e';

/// Средний урон по костям: «2d6» → 7, «1d8» → 5 (половина вверх). Нет костей — 1.
int averageDamage(String? dice) {
  final m = RegExp(r'^(\d+)d(\d+)').firstMatch(dice ?? '');
  if (m == null) return int.tryParse(dice ?? '') ?? 1;
  final n = int.parse(m[1]!), sides = int.parse(m[2]!);
  return (n * (sides + 1) / 2).round();
}

ItemKind kindOf(Open5eItem o) => o.damageDice != null
    ? ItemKind.weapon
    : o.armorClass != null
    ? ItemKind.armor
    : const {'potion', 'scroll', 'ammunition'}.contains(o.category)
    ? ItemKind.consumable
    : ItemKind.misc;

Rarity rarityOf(Open5eItem o) => switch (o.rarity) {
  'uncommon' => Rarity.uncommon,
  'rare' => Rarity.rare,
  'very-rare' => Rarity.epic,
  'legendary' || 'artifact' => Rarity.legendary,
  _ => Rarity.common,
};

/// План из одной операции: создать предмет по образцу, с новым slug и источником.
Plan importPlan(Open5eItem o, WorldSnapshot world) {
  final kind = kindOf(o);
  final slug = uniqueSlug(o.name, world.items.map((i) => i.slug));
  return Plan(
    summary: 'Импорт из Open5e: ${o.name}',
    ops: [
      PlanOp(
        action: OpAction.create,
        type: OpType.item,
        slug: slug,
        fields: {
          'title': o.name,
          'kind': kind.name,
          'rarity': rarityOf(o).name,
          'level': 1,
          if (kind == ItemKind.weapon) 'damage': averageDamage(o.damageDice),
          if (kind == ItemKind.armor) 'defense': o.armorClass!,
          'price': (o.cost ?? 0).round(),
          'source': open5eSource,
          'source_ref': o.key,
        },
      ),
    ],
  );
}
