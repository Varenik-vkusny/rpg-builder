// Прибор приёмки «Затопи копи» (live/kopi_flood_judge.dart) — умеет краснеть: прошлый живой
// прогон 01.10 (Штольня не тронута, слизень удалён без вопроса) приёмку не проходит.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';

import '../live/kopi_flood_judge.dart';

void main() {
  final saved = jsonDecode(
    File('test/fixtures/kopi_flood_2026-10-01.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final old = Plan.fromJson(saved['plan'] as Map<String, dynamic>);
  final asked = saved['questions_asked'] as int;

  const shaft = PlanOp(
    action: OpAction.update,
    type: OpType.location,
    slug: 'shtolnya_3',
    fields: {'description': 'затоплена по пояс'},
  );
  Plan withOps(List<PlanOp> ops) => Plan(summary: old.summary, ops: ops);

  test('прошлый прогон 01.10 не проходит: штольня не изменилась, слизень удалён молча', () {
    expect(judgeKopiFlood(old, questionsAsked: asked), [
      contains('описание места внутри копей не изменилось'),
      contains('«slizen» удалён без вопроса'),
    ]);
  });

  test(
    'спросили автора — удаление жителя не провал, но штольня всё равно нужна',
    () {
      expect(judgeKopiFlood(old, questionsAsked: 1), [
        contains('описание места внутри копей не изменилось'),
      ]);
    },
  );

  test('штольня изменена, жителя удалили молча — провал', () {
    expect(judgeKopiFlood(withOps([...old.ops, shaft]), questionsAsked: 0), [
      contains('«slizen» удалён без вопроса'),
    ]);
  });

  test('штольня — только переименование без описания — провал', () {
    final renamed = PlanOp(
      action: OpAction.update,
      type: OpType.location,
      slug: 'shtolnya_3',
      fields: const {'title': 'Затопленная штольня'},
    );
    expect(judgeKopiFlood(withOps([renamed]), questionsAsked: 0), hasLength(1));
  });

  test('штольня описана заново, жителей не удаляли — проходит', () {
    final ok = withOps([
      ...old.ops.where((o) => o.type != OpType.character),
      shaft,
    ]);
    expect(judgeKopiFlood(ok, questionsAsked: 0), isEmpty);
  });
}
