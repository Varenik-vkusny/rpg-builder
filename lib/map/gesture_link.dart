// Жест «провёл от объекта к объекту» (5е): вид связи угадан по паре, число — колёсиком,
// где вариантов несколько (квест → житель) — меню. Связь — одна строковая операция
// «создать», как правка вручную: проверка, история, откат (gesture_path.dart).
import '../check/world_check.dart';
import '../content/character.dart';
import '../content/event.dart';
import '../content/manual_edit.dart';
import '../content/quest.dart';
import 'holst_scene.dart';

/// Какой связью станет пара. [wheel] — что крутит колёсико; [menu] — выбрать вид.
enum LinkKind { loot, talk, kill, collect, pass, eventEnemy, eventItem }

enum Wheel { none, count, chance }

typedef LinkRule = ({
  LinkKind? kind,
  bool menu,
  Wheel wheel,
  String from,
  String to,
});

String linkWord(LinkKind k) => switch (k) {
  LinkKind.loot => 'роняет',
  LinkKind.talk => 'поговорить',
  LinkKind.kill => 'убить',
  LinkKind.collect => 'собрать',
  LinkKind.pass => 'пройти',
  LinkKind.eventEnemy => 'враги',
  LinkKind.eventItem => 'лежит',
};

Wheel wheelOf(LinkKind k) => switch (k) {
  LinkKind.loot => Wheel.chance,
  LinkKind.kill || LinkKind.eventEnemy => Wheel.count,
  _ => Wheel.none,
};

/// Пара [a] → [b] в любом порядке: кто владелец связи (from) и какой вид. null — не связываются.
LinkRule? linkRule(HolstToken a, HolstToken b) {
  LinkRule? one(HolstToken x, HolstToken y) {
    LinkRule r(LinkKind k) =>
        (kind: k, menu: false, wheel: wheelOf(k), from: x.id, to: y.id);
    return switch ((x.kind, y.kind)) {
      (TokenKind.enemy, TokenKind.item) => r(LinkKind.loot),
      (TokenKind.quest, TokenKind.npc) => (
        kind: null,
        menu: true,
        wheel: Wheel.none,
        from: x.id,
        to: y.id,
      ),
      (TokenKind.quest, TokenKind.enemy) => r(LinkKind.kill),
      (TokenKind.quest, TokenKind.item) => r(LinkKind.collect),
      (TokenKind.quest, TokenKind.event) => r(LinkKind.pass),
      (TokenKind.event, TokenKind.enemy) => r(LinkKind.eventEnemy),
      (TokenKind.event, TokenKind.item) => r(LinkKind.eventItem),
      _ => null,
    };
  }

  return one(a, b) ?? one(b, a);
}

/// Связь [kind] уже есть — второй такой не бывает (кроме шагов квеста «убить» и
/// «поговорить»: шаги одного вида с разными целями — норма, с той же целью — повтор).
bool linked(WorldSnapshot w, LinkKind kind, String from, String to) =>
    switch (kind) {
      LinkKind.loot => w.characters.any(
        (c) => c.id == from && c.loot.any((l) => l.itemId == to),
      ),
      LinkKind.eventEnemy => w.events.any(
        (e) => e.id == from && e.enemies.any((x) => x.characterId == to),
      ),
      LinkKind.eventItem => w.events.any(
        (e) => e.id == from && e.itemIds.contains(to),
      ),
      _ => w.quests.any(
        (q) => q.id == from && q.steps.any((s) => s.targetId == to),
      ),
    };

/// Слова связи со значением колёсика: «роняет 25%», «убить ×3», «пройти».
String linkLabel(LinkKind k, int value) => switch (wheelOf(k)) {
  Wheel.chance => '${linkWord(k)} $value%',
  Wheel.count => '${linkWord(k)} ×$value',
  Wheel.none => linkWord(k),
};

/// Правка: новая связь [kind] от [from] к [to] со значением [value] (шанс или сколько).
ManualEdit linkByGesture(
  String worldId,
  WorldSnapshot w,
  LinkKind kind,
  String from,
  String to,
  int value,
) {
  final all = worldTokens(w);
  final a = all[from]!, b = all[to]!;
  final title =
      'Холст: связь ${a.title} — ${linkLabel(kind, value)} — ${b.title}';
  switch (kind) {
    case LinkKind.loot:
      final row = {
        'project_id': worldId,
        'character_id': from,
        'item_id': to,
        'chance': value.toDouble(),
      };
      return ManualEdit(
        title: title,
        slug: a.slug,
        ops: [rowOp('create', 'loot', '${a.slug}/${b.slug}', row)],
        applyTo: (s) => _swap(
          s,
          characters: [
            for (final c in s.characters)
              c.id == from ? _withLoot(c, to, value.toDouble()) : c,
          ],
        ),
      );
    case LinkKind.eventEnemy || LinkKind.eventItem:
      final enemy = kind == LinkKind.eventEnemy;
      final row = {
        'project_id': worldId,
        'event_id': from,
        if (enemy) ...{'character_id': to, 'amount': value} else 'item_id': to,
      };
      return ManualEdit(
        title: title,
        slug: a.slug,
        ops: [
          rowOp(
            'create',
            enemy ? 'event_enemy' : 'event_item',
            '${a.slug}/${b.slug}',
            row,
          ),
        ],
        applyTo: (s) => _swap(
          s,
          events: [
            for (final e in s.events)
              e.id != from
                  ? e
                  : Event(
                      id: e.id,
                      slug: e.slug,
                      title: e.title,
                      description: e.description,
                      locationId: e.locationId,
                      enemies: [
                        ...e.enemies,
                        if (enemy) EventEnemy(characterId: to, amount: value),
                      ],
                      items: [
                        ...e.items,
                        if (!enemy) EventItem(itemId: to),
                      ],
                    ),
          ],
        ),
      );
    case LinkKind.talk || LinkKind.kill || LinkKind.collect || LinkKind.pass:
      final q = w.quests.firstWhere((x) => x.id == from);
      final step = QuestStep(
        kind: switch (kind) {
          LinkKind.talk => StepKind.talk,
          LinkKind.kill => StepKind.kill,
          LinkKind.collect => StepKind.collect,
          _ => StepKind.event,
        },
        targetId: to,
        amount: kind == LinkKind.kill || kind == LinkKind.collect
            ? value
            : null,
      );
      final pos = q.steps.length + 1;
      final row = {
        'project_id': worldId,
        'quest_id': from,
        'position': pos,
        'kind': step.kind.name,
        'character_id': kind == LinkKind.talk || kind == LinkKind.kill
            ? to
            : null,
        'item_id': kind == LinkKind.collect ? to : null,
        'location_id': null,
        'event_id': kind == LinkKind.pass ? to : null,
        'amount': step.amount,
      };
      return ManualEdit(
        title: title,
        slug: q.slug,
        ops: [rowOp('create', 'quest_step', '${q.slug}#$pos', row)],
        applyTo: (s) => _swap(
          s,
          quests: [
            for (final x in s.quests)
              x.id != from
                  ? x
                  : Quest(
                      id: x.id,
                      slug: x.slug,
                      title: x.title,
                      description: x.description,
                      giverId: x.giverId,
                      steps: [...x.steps, step],
                      rewardIds: x.rewardIds,
                    ),
          ],
        ),
      );
  }
}

Character _withLoot(Character c, String item, double chance) => Character(
  id: c.id,
  slug: c.slug,
  title: c.title,
  description: c.description,
  role: c.role,
  locationId: c.locationId,
  loot: [
    ...c.loot,
    LootDrop(itemId: item, chance: chance),
  ],
  level: c.level,
  hp: c.hp,
  attack: c.attack,
);

WorldSnapshot _swap(
  WorldSnapshot s, {
  List<Character>? characters,
  List<Event>? events,
  List<Quest>? quests,
}) => WorldSnapshot(
  locations: s.locations,
  items: s.items,
  characters: characters ?? s.characters,
  quests: quests ?? s.quests,
  events: events ?? s.events,
);
