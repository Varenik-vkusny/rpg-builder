// Прибор «причина „Не получится“ словами автора» (владелец 20.11): в плане на холсте
// не «Операция 1 (Создать · Персонаж «Гоблин-разведчик»): не задано: роль»,
// а «Гоблину-разведчику не задана роль». Текст проверки для ассистента — прежний.
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';
import 'package:rpg_builder/assistant/plan_preview.dart';
import 'package:rpg_builder/assistant/assistant_service.dart';
import 'package:rpg_builder/check/world_check.dart';
import 'package:rpg_builder/map/holst_plan.dart';
import 'package:rpg_builder/map/plan_why.dart';

import 'assistant_fixtures.dart';

void main() {
  test('имя — в дательном падеже', () {
    expect(dative('Гоблин-разведчик'), 'Гоблину-разведчику');
    expect(dative('Гоблин‑страж'), 'Гоблину‑стражу');
    expect(dative('Старый бригадир'), 'Старому бригадиру');
    expect(dative('Кирка'), 'Кирке');
    expect(dative('Старая шахта'), 'Старой шахте');
    expect(dative('Синий слизень'), isNull); // «ь» — не угадать
    expect(dative('Сергей'), 'Сергею');
    expect(dative('Мария'), 'Марии');
    expect(dative('Штольня №3'), 'Штольне №3');
    expect(dative('Пепельные копи'), isNull);
    expect(dative('Купец'), isNull);
  });

  test('не задано поле — одной фразой автора', () {
    expect(
      opWhy('Гоблин-разведчик', 'не задано: роль'),
      'Гоблину-разведчику не задана роль',
    );
    expect(opWhy('Кирка', 'не задано: урон'), 'Кирке не задан урон');
    expect(opWhy('Обвал', 'не задано: название'), 'Обвалу не задано название');
    // Падеж не угадать — без падежа, но без «Операция» и «не задано:».
    expect(
      opWhy('Пепельные копи', 'не задано: уровни'),
      'Не заданы уровни: Пепельные копи',
    );
  });

  test('под строкой плана — без имени и без служебного', () {
    expect(rowWhy('не задано: роль'), 'не задана роль');
    expect(rowWhy('локации «zaboy_9» нет в мире'), 'в мире нет такого места');
    expect(rowWhy('slug «kirka» уже занят'), 'уже есть в мире');
    expect(rowWhy('квест выдаёт только житель'), 'квест выдаёт только житель');
  });

  test('служебное не показывается: ключи, номера операций', () {
    expect(
      opWhy('nikto', 'персонажа «nikto» нет в мире'),
      'В мире нет такого персонажа',
    );
    expect(
      opWhy('Слизень', 'локации «zaboy_9» нет в мире'),
      'Слизень: в мире нет такого места',
    );
    expect(opWhy('Кирка', 'slug «kirka» уже занят'), 'Кирка уже есть в мире');
    final bad = opWhy('Кирка', 'slug «Кирка» — только латиница, цифры и «_»');
    expect(bad, isNot(contains('slug')));
    expect(bad, isNot(contains('латиница')));
    expect(
      opWhy('Слизень', 'роль персонажа не меняется'),
      'Слизень: роль персонажа не меняется',
    );
  });

  test('план целиком: первая ошибка — словами автора', () async {
    final c = await minesContent();
    final world = await c.snapshotOf(minesId);
    final plan = Plan.fromJson({
      'summary': 'гоблин',
      'ops': [
        {
          'action': 'create',
          'type': 'character',
          'slug': 'goblin_scout',
          'fields': {'title': 'Гоблин-разведчик', 'role': null},
        },
      ],
    });
    final p = previewPlan(world, plan, null);
    // Текст для ассистента и экрана проверки — прежний, с номером операции.
    expect(p.of(Severity.error).first.message, startsWith('Операция 1 ('));
    expect(planWhy(p), 'Гоблину-разведчику не задана роль');
    // Под строкой плана — та же причина без имени (имя уже в строке).
    final row = planRows(p.ops, p.copy).single;
    expect(row.title, 'Гоблин-разведчик');
    expect(row.error, 'не задана роль');
    expect(
      planWhy(
        previewPlan(world, Plan.fromJson({'summary': '', 'ops': []}), null),
      ),
      isNull,
    );
  });

  test('правка вне выбранного — словами, без ключей', () async {
    final c = await minesContent();
    final world = await c.snapshotOf(minesId);
    final plan = Plan.fromJson({
      'summary': 'рынок',
      'ops': [
        {
          'action': 'update',
          'type': 'location',
          'slug': 'rynok',
          'fields': {'description': 'сгорел'},
        },
      ],
    });
    final p = previewPlan(
      world,
      plan,
      const Scope(ScopeType.location, 'shtolnya_3'),
    );
    expect(p.outside, isNotEmpty);
    expect(planWhy(p), 'Рынок — не из выбранного');
  });
}
