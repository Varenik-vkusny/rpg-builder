// Значки вида (5д, выбор владельца 19.10): отобранные силуэты game-icons.net (CC BY 3.0)
// лежат в assets/glyphs и работают без сети. Имя значка хранится в поле icon жителя и
// предмета; неизвестное имя (значок убран из набора) — как будто значка нет.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Авторство набора — под выбором значка.
const glyphCredit = 'Значки: game-icons.net, CC BY 3.0';

/// Группы выбора: название группы и значки с русскими именами.
const glyphGroups = <(String, Map<String, String>)>[
  (
    'Существа',
    {
      'skeleton': 'скелет',
      'slime': 'слизень',
      'goblin-head': 'гоблин',
      'orc-head': 'орк',
      'troll': 'тролль',
      'ogre': 'огр',
      'dragon-head': 'дракон',
      'wyvern': 'виверна',
      'hydra': 'гидра',
      'wolf-head': 'волк',
      'bear-head': 'медведь',
      'boar': 'кабан',
      'spider-face': 'паук',
      'bat': 'летучая мышь',
      'rat': 'крыса',
      'snake': 'змея',
      'scorpion': 'скорпион',
      'ghost': 'призрак',
      'shambling-zombie': 'зомби',
      'vampire-dracula': 'вампир',
      'mummy-head': 'мумия',
      'imp-laugh': 'бес',
      'devil-mask': 'демон',
      'minotaur': 'минотавр',
      'centaur': 'кентавр',
      'griffin-symbol': 'грифон',
      'kraken-tentacle': 'кракен',
      'golem-head': 'голем',
      'werewolf': 'оборотень',
      'crowned-skull': 'король-лич',
      'death-skull': 'череп',
      'frog': 'лягушка',
      'beast-eye': 'глаз чудища',
      'fairy': 'фея',
      'dinosaur-rex': 'ящер',
    },
  ),
  (
    'Люди',
    {
      'farmer': 'крестьянин',
      'miner': 'шахтёр',
      'hooded-figure': 'странник',
      'hooded-assassin': 'убийца',
      'robber': 'разбойник',
      'wizard-face': 'маг',
      'witch-face': 'ведьма',
      'warlock-hood': 'колдун',
      'swordman': 'мечник',
      'bowman': 'лучник',
      'guards': 'стража',
      'old-king': 'король',
      'queen-crown': 'королева',
      'monk-face': 'монах',
      'nun-face': 'монахиня',
      'sun-priest': 'жрец',
      'pirate-captain': 'пират',
      'cook': 'повар',
      'blacksmith': 'кузнец',
      'shop': 'торговец',
      'dwarf-face': 'гном',
      'woman-elf-face': 'эльфийка',
      'elf-helmet': 'эльф',
      'jester-hat': 'шут',
      'ninja-head': 'ниндзя',
      'cowled': 'паломник',
      'baby-face': 'ребёнок',
      'cloaked-figure-on-horseback': 'всадник',
    },
  ),
  (
    'Оружие',
    {
      'broadsword': 'меч',
      'war-pick': 'кирка',
      'battle-axe': 'топор',
      'barbed-spear': 'копьё',
      'bow-arrow': 'лук',
      'crossbow': 'арбалет',
      'mace-head': 'булава',
      'dagger-rose': 'кинжал',
      'warhammer': 'молот',
      'sickle': 'серп',
      'scythe': 'коса',
      'trident': 'трезубец',
      'whip': 'кнут',
      'sling': 'праща',
      'flail': 'цеп',
      'fairy-wand': 'волшебная палочка',
    },
  ),
  (
    'Доспехи',
    {
      'shield': 'щит',
      'chest-armor': 'кираса',
      'leather-armor': 'кожаный доспех',
      'helmet': 'шлем',
      'visored-helm': 'закрытый шлем',
      'dwarf-helmet': 'гномий шлем',
      'gauntlet': 'латная перчатка',
      'leather-boot': 'сапог',
      'cape': 'плащ',
    },
  ),
  (
    'Зелья и еда',
    {
      'potion-ball': 'зелье',
      'health-potion': 'лечебное зелье',
      'round-bottom-flask': 'колба',
      'meat': 'мясо',
      'chicken-leg': 'окорок',
      'bread': 'хлеб',
      'mushroom-gills': 'гриб',
      'herbs-bundle': 'травы',
      'cheese-wedge': 'сыр',
      'wine-bottle': 'вино',
      'fish-cooked': 'рыба',
    },
  ),
  (
    'Инструменты',
    {
      'mining': 'горняцкое дело',
      'hammer-nails': 'молоток',
      'hand-saw': 'пила',
      'lantern-flame': 'фонарь',
      'rope-coil': 'верёвка',
      'torch': 'факел',
      'fishing-pole': 'удочка',
      'mine-wagon': 'вагонетка',
    },
  ),
  (
    'Ценности',
    {
      'key': 'ключ',
      'gem-chain': 'самоцвет',
      'diamond-ring': 'кольцо',
      'gem-necklace': 'ожерелье',
      'crown': 'корона',
      'gold-bar': 'слиток',
      'coins': 'монеты',
      'scroll-unfurled': 'свиток',
      'book-cover': 'книга',
      'treasure-map': 'карта сокровищ',
      'open-treasure-chest': 'сундук',
      'locked-chest': 'запертый сундук',
      'crystal-ball': 'хрустальный шар',
      'horseshoe': 'подкова',
    },
  ),
];

/// Русское имя значка; null — такого значка в наборе нет.
String? glyphName(String id) {
  for (final (_, g) in glyphGroups) {
    if (g[id] case final name?) return name;
  }
  return null;
}

/// Силуэт значка цвета [color].
class Glyph extends StatelessWidget {
  const Glyph(this.id, {super.key, required this.size, required this.color});

  final String id;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/glyphs/$id.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: glyphName(id),
  );
}
