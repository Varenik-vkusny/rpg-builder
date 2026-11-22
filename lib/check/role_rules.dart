// Ошибки ролей (22.11): роль персонажа можно сменить формой — тогда связи, которые на
// ней держатся, проверка ловит, и правка не сохраняется (правило 4): квест выдаёт только
// житель, убить можно только врага, в событии стоят только враги. Раньше это стерёг
// только план ассистента, а роль не менялась вовсе.
import '../content/character.dart';
import '../content/quest.dart';
import 'world_check.dart';

List<Problem> roleErrors(WorldSnapshot w) {
  final roles = {for (final c in w.characters) c.id: c};
  String name(String id) => '«${roles[id]?.title ?? '?'}»';
  bool isNot(String id, Role role) =>
      roles[id] != null && roles[id]!.role != role;
  return [
    for (final q in w.quests) ...[
      if (q.giverId != null && isNot(q.giverId!, Role.npc))
        Problem(
          Severity.error,
          'quest_giver_not_npc',
          q.id,
          '«${q.title}»: квест выдаёт только житель, а ${name(q.giverId!)} — '
              '${roles[q.giverId!]!.role.label.toLowerCase()}',
        ),
      for (final (i, s) in q.steps.indexed)
        if (s.kind == StepKind.kill && isNot(s.targetId, Role.enemy))
          Problem(
            Severity.error,
            'quest_kill_not_enemy',
            q.id,
            '«${q.title}», шаг ${i + 1}: убить можно только врага, '
                'а ${name(s.targetId)} — '
                '${roles[s.targetId]!.role.label.toLowerCase()}',
          ),
    ],
    for (final e in w.events)
      for (final x in e.enemies)
        if (isNot(x.characterId, Role.enemy))
          Problem(
            Severity.error,
            'event_enemy_not_enemy',
            e.id,
            '«${e.title}»: в событии стоят только враги, '
                'а ${name(x.characterId)} — '
                '${roles[x.characterId]!.role.label.toLowerCase()}',
          ),
  ];
}
