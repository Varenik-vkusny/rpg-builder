// Прибор приёмки «Затопи копи» (live/kopi_flood_judge.dart) — умеет краснеть на сохранённых
// живых прогонах: 01.10 (Штольня не тронута, слизень удалён молча) и 02.10 v35 (Штольня
// изменена, но слизень удалён, а спросили автора только про Штольню).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/assistant/plan.dart';

import '../live/kopi_flood_judge.dart';

typedef Saved = ({Plan plan, List<String> questions});

Saved load(String name) {
  final j = jsonDecode(
    File('test/fixtures/$name').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (
    plan: Plan.fromJson(j['plan'] as Map<String, dynamic>),
    questions: [for (final q in j['questions'] as List) q as String],
  );
}

const titles = {'slizen': 'Слизень'};
const aboutSlime =
    'Слизни не могут жить в воде. Что делать со Слизнем? Удалить Слизня';

List<String> judge(Plan p, List<String> questions) =>
    judgeKopiFlood(p, questions: questions, titles: titles);

void main() {
  final old = load('kopi_flood_2026-10-01.json');
  final v35 = load('kopi_flood_2026-10-02_v35.json');

  const shaft = PlanOp(
    action: OpAction.update,
    type: OpType.location,
    slug: 'shtolnya_3',
    fields: {'description': 'затоплена по пояс'},
  );
  Plan withOps(List<PlanOp> ops) => Plan(summary: old.plan.summary, ops: ops);

  test(
    'прогон 01.10 не проходит: штольня не изменилась, слизень удалён молча',
    () {
      expect(judge(old.plan, old.questions), [
        contains('описание места внутри копей не изменилось'),
        contains('«slizen» удалён без вопроса'),
      ]);
    },
  );

  test(
    'прогон 02.10 v35 не проходит: спросили про штольню, а не про слизня',
    () {
      expect(judge(v35.plan, v35.questions), [
        contains('«slizen» удалён без вопроса'),
      ]);
    },
  );

  test(
    'спросили про слизня — удаление не провал, но штольня всё равно нужна',
    () {
      expect(judge(old.plan, [aboutSlime]), [
        contains('описание места внутри копей не изменилось'),
      ]);
    },
  );

  test('вопрос называет слизня в другом падеже — засчитан', () {
    expect(
      judge(v35.plan, [...v35.questions, 'Что делать со слизнем?']),
      isEmpty,
    );
  });

  test('житель спрошен, только если вопрос называет всё его имя', () {
    // Старое правило (первые 4 буквы имени) засчитало бы вопрос про мир «Пепельные копи».
    expect(
      askedAbout(['Пепельные копи: затопить?'], 'Пепельный слизень'),
      isFalse,
    );
    expect(
      askedAbout(['Что делать с пепельным слизнем?'], 'Пепельный слизень'),
      isTrue,
    );
    // Вопрос сервера про места внутри — не про жителей.
    expect(
      askedAbout(['Места внутри «Копи»: хозяин копи там?'], 'Хозяин копи'),
      isFalse,
    );
  });

  test('штольня — только переименование без описания — провал', () {
    const renamed = PlanOp(
      action: OpAction.update,
      type: OpType.location,
      slug: 'shtolnya_3',
      fields: {'title': 'Затопленная штольня'},
    );
    expect(judge(withOps([renamed]), const []), hasLength(1));
  });

  test('штольня описана заново, жителей не удаляли — проходит', () {
    final ok = withOps([
      ...old.plan.ops.where((o) => o.type != OpType.character),
      shaft,
    ]);
    expect(judge(ok, const []), isEmpty);
  });
}
