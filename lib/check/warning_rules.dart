// Предупреждения проверки мира — чистый Dart, как и ошибки (world_check.dart).
import '../content/character.dart';
import '../content/item.dart';
import 'world_check.dart';

/// Предупреждения: предмет нельзя получить, урон выше потолка, атака врага
/// выше потолка, враг выше уровней локации, эпический дешевле медианы редких,
/// повтор названий.
List<Problem> warningRules(WorldSnapshot w) => [
  ..._unobtainable(w),
  ..._damageOverCeiling(w),
  ..._enemyAttackOverCeiling(w),
  ..._enemyOverLocation(w),
  ..._epicCheaperThanRare(w),
  ..._duplicateTitles(w),
];

/// Множитель редкости в потолке урона.
double rarityMultiplier(Rarity r) => switch (r) {
  Rarity.common => 1.0,
  Rarity.uncommon => 1.2,
  Rarity.rare => 1.5,
  Rarity.epic => 1.9,
  Rarity.legendary => 2.4,
};

/// Потолок урона: 4 + уровень × 2 × множитель редкости.
double damageCeiling(int level, Rarity rarity) =>
    4 + level * 2 * rarityMultiplier(rarity);

Problem _warn(String rule, String id, String message) =>
    Problem(Severity.warning, rule, id, message);

/// 8.0 → «8», 6.4 → «6.4».
String _num(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// Предмет не выпадает ни из одного врага и не выдаётся наградой.
Iterable<Problem> _unobtainable(WorldSnapshot w) {
  final obtainable = {
    for (final c in w.characters)
      for (final l in c.loot) l.itemId,
    for (final q in w.quests) ...q.rewardIds,
  };
  return [
    for (final i in w.items)
      if (!obtainable.contains(i.id))
        _warn(
          'item_unobtainable',
          i.id,
          '«${i.title}» нельзя получить: не выпадает и не выдаётся наградой',
        ),
  ];
}

Iterable<Problem> _damageOverCeiling(WorldSnapshot w) => [
  for (final i in w.items)
    if (i.damage != null && i.damage! > damageCeiling(i.level, i.rarity))
      _warn(
        'damage_over_ceiling',
        i.id,
        '«${i.title}»: урон ${i.damage} выше потолка '
            '${_num(damageCeiling(i.level, i.rarity))} '
            '(ур. ${i.level}, ${i.rarity.label.toLowerCase()})',
      ),
];

/// Потолок атаки врага — как урона обычного предмета его уровня: 4 + уровень × 2.
double attackCeiling(int level) => damageCeiling(level, Rarity.common);

Iterable<Problem> _enemyAttackOverCeiling(WorldSnapshot w) => [
  for (final c in w.characters)
    if (c.role == Role.enemy && c.attack > attackCeiling(c.level))
      _warn(
        'attack_over_ceiling',
        c.id,
        '«${c.title}»: атака ${c.attack} выше потолка '
            '${_num(attackCeiling(c.level))} (ур. ${c.level})',
      ),
];

/// Враг выше верхнего уровня своей локации.
Iterable<Problem> _enemyOverLocation(WorldSnapshot w) {
  final byId = {for (final l in w.locations) l.id: l};
  return [
    for (final c in w.characters)
      if (byId[c.locationId] case final l?
          when c.role == Role.enemy && c.level > l.levelMax)
        _warn(
          'enemy_over_location',
          c.id,
          '«${c.title}»: ур. ${c.level} выше уровней локации '
              '«${l.title}» (${l.levelMin}–${l.levelMax})',
        ),
  ];
}

/// Эпический дешевле медианы цен редких. Редких нет — сравнивать не с чем.
Iterable<Problem> _epicCheaperThanRare(WorldSnapshot w) {
  final rare = [
    for (final i in w.items)
      if (i.rarity == Rarity.rare) i.price,
  ]..sort();
  if (rare.isEmpty) return const [];
  final m = rare.length ~/ 2;
  final median = rare.length.isOdd
      ? rare[m].toDouble()
      : (rare[m - 1] + rare[m]) / 2;
  return [
    for (final i in w.items)
      if (i.rarity == Rarity.epic && i.price < median)
        _warn(
          'epic_cheaper_than_rare',
          i.id,
          '«${i.title}»: эпический за ${i.price} зол. дешевле '
              'медианы редких ${_num(median)} зол.',
        ),
  ];
}

/// Повтор — среди объектов одного вида, без учёта регистра и пробелов по краям.
Iterable<Problem> _duplicateTitles(WorldSnapshot w) {
  final kinds = <String, List<(String, String)>>{
    'локаций': [for (final x in w.locations) (x.id, x.title)],
    'предметов': [for (final x in w.items) (x.id, x.title)],
    'персонажей': [for (final x in w.characters) (x.id, x.title)],
    'квестов': [for (final x in w.quests) (x.id, x.title)],
  };
  return [
    for (final MapEntry(key: kind, value: objects) in kinds.entries)
      for (final same in _groupByTitle(objects).where((g) => g.length > 1))
        _warn(
          'duplicate_title',
          same.first.$1,
          '«${same.first.$2}» — название повторяется у ${same.length} $kind',
        ),
  ];
}

List<List<(String, String)>> _groupByTitle(List<(String, String)> objects) {
  final groups = <String, List<(String, String)>>{};
  for (final o in objects) {
    groups.putIfAbsent(o.$2.trim().toLowerCase(), () => []).add(o);
  }
  return groups.values.toList();
}
