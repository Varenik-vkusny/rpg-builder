// Враг из справочника (5д, решение владельца 19.10 «наши 3 числа + оригинал при себе»):
// опасность → уровень, здоровье → здоровье, средний урон первой атаки → атака; значок
// подбирается по имени, иначе по типу существа; карточка оригинала — при враге, в экспорт.
// Пишется одной строковой операцией «создать» — правкой вручную: проверка на копии,
// история, откат (функции плана на сервере не трогаются).
import 'dart:math';

import '../check/world_check.dart';
import '../content/character.dart';
import '../content/manual_edit.dart';
import '../content/slug.dart';
import '../map/gesture_create.dart' show newId;
import 'open5e_api.dart';
import 'open5e_import.dart' show open5eSource;

/// Опасность 1/4 → ур. 1, 2 → ур. 2, 10.4 → ур. 10.
int levelOfChallenge(double cr) => max(1, cr.round());

/// Средний урон: 2d6+3 → 10 (половина вверх). Атак нет — 0.
int attackOf(Open5eCreature c) => switch (c.firstAttack) {
  (final n, final d, final b) => (n * (d + 1) / 2 + b).round(),
  null => 0,
};

/// Слово в имени → значок: точнее типа («Skeleton» — скелет, а не просто нежить).
const _byName = {
  'skeleton': 'skeleton',
  'zombie': 'shambling-zombie',
  'ghoul': 'shambling-zombie',
  'mummy': 'mummy-head',
  'vampire': 'vampire-dracula',
  'ghost': 'ghost',
  'specter': 'ghost',
  'wraith': 'ghost',
  'lich': 'crowned-skull',
  'goblin': 'goblin-head',
  'hobgoblin': 'goblin-head',
  'orc': 'orc-head',
  'troll': 'troll',
  'ogre': 'ogre',
  'dragon': 'dragon-head',
  'wyvern': 'wyvern',
  'hydra': 'hydra',
  'wolf': 'wolf-head',
  'werewolf': 'werewolf',
  'bear': 'bear-head',
  'boar': 'boar',
  'spider': 'spider-face',
  'bat': 'bat',
  'rat': 'rat',
  'snake': 'snake',
  'serpent': 'snake',
  'scorpion': 'scorpion',
  'imp': 'imp-laugh',
  'demon': 'devil-mask',
  'devil': 'devil-mask',
  'minotaur': 'minotaur',
  'centaur': 'centaur',
  'griffon': 'griffin-symbol',
  'kraken': 'kraken-tentacle',
  'golem': 'golem-head',
  'frog': 'frog',
  'toad': 'frog',
  'bandit': 'robber',
  'thug': 'robber',
  'assassin': 'hooded-assassin',
  'cultist': 'hooded-figure',
  'mage': 'wizard-face',
  'priest': 'sun-priest',
  'guard': 'guards',
  'knight': 'swordman',
  'pirate': 'pirate-captain',
};

/// Тип существа → значок, если по имени не нашлось.
const _byType = {
  'aberration': 'beast-eye',
  'beast': 'wolf-head',
  'celestial': 'sun-priest',
  'construct': 'golem-head',
  'dragon': 'dragon-head',
  'elemental': 'ghost',
  'fey': 'fairy',
  'fiend': 'devil-mask',
  'giant': 'ogre',
  'humanoid': 'hooded-figure',
  'monstrosity': 'minotaur',
  'ooze': 'slime',
  'plant': 'mushroom-gills',
  'undead': 'death-skull',
};

/// Значок образца: по слову имени, иначе по типу; не нашлось — null (значок по роли).
String? glyphOf(Open5eCreature c) {
  final words = c.name.toLowerCase().split(RegExp(r'[^a-z]+'));
  for (final w in words) {
    if (_byName[w] case final g?) return g;
  }
  return _byType[c.type];
}

/// Импорт врага: строка «создать» с числами, значком, источником и карточкой оригинала.
/// [title] — имя в мире (перевод); slug — от оригинала: `skeleton` понятнее коду игры.
({ManualEdit edit, String id}) importEnemy(
  String worldId,
  WorldSnapshot w,
  Open5eCreature c, {
  String? title,
}) {
  final id = newId();
  final name = title ?? c.name;
  final slug = uniqueSlug(c.name, w.characters.map((x) => x.slug));
  final enemy = Character(
    id: id,
    slug: slug,
    title: name,
    description: '',
    role: Role.enemy,
    locationId: null,
    loot: const [],
    level: levelOfChallenge(c.challenge),
    hp: max(1, c.hp),
    attack: attackOf(c),
    icon: glyphOf(c),
    origin: Origin(source: open5eSource, ref: c.key, card: c.raw),
  );
  return (
    id: id,
    edit: ManualEdit(
      title: 'Импорт из Open5e: $name',
      slug: slug,
      ops: [
        rowOp('create', 'character', slug, {
          'id': id,
          'project_id': worldId,
          'slug': slug,
          'title': name,
          'description': '',
          'role': 'enemy',
          'level': enemy.level,
          'hp': enemy.hp,
          'attack': enemy.attack,
          'icon': enemy.icon,
          'source': open5eSource,
          'source_ref': c.key,
          'source_card': c.raw,
        }),
      ],
      applyTo: (s) => WorldSnapshot(
        locations: s.locations,
        items: s.items,
        characters: [...s.characters, enemy],
        quests: s.quests,
        events: s.events,
      ),
    ),
  );
}
