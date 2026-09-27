// Подписи плана словами автора: «Изменить · Локация «Штольня №3»», «Атака: 14 → 8».
import '../check/world_check.dart';
import '../content/character.dart';
import '../content/item.dart';
import '../content/quest.dart';
import 'plan.dart';

const _fieldLabels = {
  'title': 'Название',
  'description': 'Описание',
  'level_min': 'Уровни от',
  'level_max': 'Уровни до',
  'kind': 'Вид',
  'rarity': 'Редкость',
  'level': 'Уровень',
  'damage': 'Урон',
  'defense': 'Защита',
  'price': 'Цена',
  'source': 'Источник',
  'source_ref': 'Образец',
  'role': 'Роль',
  'hp': 'Здоровье',
  'attack': 'Атака',
  'location': 'Локация',
  'giver': 'Выдаёт',
  'chance': 'Шанс',
  'amount': 'Количество',
};

String fieldLabel(String f) => _fieldLabels[f] ?? f;

const _actions = {
  OpAction.create: 'Создать',
  OpAction.update: 'Изменить',
  OpAction.delete: 'Удалить',
};

const _types = {
  OpType.location: 'Локация',
  OpType.item: 'Предмет',
  OpType.character: 'Персонаж',
  OpType.quest: 'Квест',
  OpType.loot: 'Добыча',
  OpType.questStep: 'Шаг квеста',
  OpType.questReward: 'Награда',
};

/// Заголовок операции из журнала: «Изменить · Локация «Штольня №3»».
String journalOpTitle(String action, String type, String what) {
  final t = opTypeByName(type);
  return '${_actions[OpAction.values.byName(action)]} · ${t == null ? type : _types[t]} $what';
}

/// Заголовок операции по частям для карточки: «Изменить · Шаг квеста «Обвал», шаг 2»
/// → (Изменить, Шаг квеста, «Обвал», шаг 2). Одиночное название — без кавычек.
(String action, String type, String name) splitOpTitle(String title) {
  final dot = title.indexOf(' · ');
  final action = dot < 0 ? '' : title.substring(0, dot);
  final rest = dot < 0 ? title : title.substring(dot + 3);
  final q = rest.indexOf(' «');
  if (q < 0) return (action, rest, '');
  final what = rest.substring(q + 1);
  final single = RegExp(r'^«([^»]*)»$').firstMatch(what);
  return (action, rest.substring(0, q), single?.group(1) ?? what);
}

/// Подписи по текущему состоянию копии мира: названия берутся из [world].
class PlanLabels {
  PlanLabels(this.world);
  final WorldSnapshot Function() world;

  /// Название объекта по виду и slug; нет в мире — сам slug.
  String titleOf(String type, String? slug) {
    final w = world();
    final found = switch (type) {
      'location' =>
        w.locations.where((x) => x.slug == slug).map((x) => x.title),
      'item' => w.items.where((x) => x.slug == slug).map((x) => x.title),
      'character' =>
        w.characters.where((x) => x.slug == slug).map((x) => x.title),
      _ => w.quests.where((x) => x.slug == slug).map((x) => x.title),
    };
    return '«${found.firstOrNull ?? slug}»';
  }

  /// «Изменить · Локация «Штольня №3»», «Создать · Добыча «Утопленник» → «Ключ»».
  String opTitle(PlanOp op) {
    final what = switch (op.type) {
      OpType.loot =>
        '${titleOf('character', op.character)} → ${titleOf('item', op.item)}',
      OpType.questStep => '${titleOf('quest', op.quest)}, шаг ${op.position}',
      OpType.questReward =>
        '${titleOf('quest', op.quest)} → ${titleOf('item', op.item)}',
      _ when op.action == OpAction.create => '«${op.str('title') ?? op.slug}»',
      _ => titleOf(op.typeName, op.slug),
    };
    return '${_actions[op.action]} · ${_types[op.type]} $what';
  }

  /// Значение поля словами: id → название, вид и редкость → подпись.
  String? value(String field, Object? raw) {
    if (raw == null) return null;
    final w = world();
    String byId(Iterable<(String, String)> pairs) =>
        pairs.where((p) => p.$1 == raw).map((p) => p.$2).firstOrNull ?? '?';
    return switch (field) {
      'location' => byId(w.locations.map((l) => (l.id, l.title))),
      'giver' => byId(w.characters.map((c) => (c.id, c.title))),
      'kind' => ItemKind.values.byName(raw as String).label,
      'rarity' => Rarity.values.byName(raw as String).label,
      'role' => Role.values.byName(raw as String).label,
      'chance' => LootDrop(
        itemId: '',
        chance: (raw as num).toDouble(),
      ).chanceLabel,
      _ => '$raw',
    };
  }

  /// «Убить: Пепельный слизень × 4».
  String step(QuestStep s) => s.label(world().titles[s.targetId] ?? '?');
}
