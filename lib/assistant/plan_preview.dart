// План на копии мира целиком: операции, область и те же правила проверки,
// что на экране «Проверка мира» (VISION.md, правило 7).
import '../check/world_check.dart';
import 'assistant_service.dart';
import 'plan.dart';
import 'plan_apply.dart';
import 'scope.dart';

class PlanPreview {
  const PlanPreview(
    this.copy,
    this.ops,
    this.outside,
    this.problems,
    this.fresh,
  );

  /// Мир после плана — только в памяти.
  final WorldSnapshot copy;
  final List<OpResult> ops;

  /// Номера операций вне области → что именно вне её.
  final Map<int, List<String>> outside;

  /// Все проблемы копии: невыполнимые операции, вне области, ошибки и предупреждения мира.
  final List<Problem> problems;

  /// Проблемы, которых не было в мире до плана, — их план и принёс.
  final List<Problem> fresh;

  List<Problem> of(Severity s) => [
    for (final p in problems)
      if (p.severity == s) p,
  ];

  /// Ошибка блокирует «Применить» (правило 4). Предупреждение — нет.
  bool get hasErrors => of(Severity.error).isNotEmpty;
}

String _id(Problem p) => '${p.rule}|${p.objectId}|${p.message}';

PlanPreview previewPlan(WorldSnapshot world, Plan plan, Scope scope) {
  final (copy, ops) = applyToCopy(world, plan);
  final outside = outOfScope(plan, scopeOf(world, scope));
  final problems = [
    for (final (i, r) in ops.indexed)
      if (r.error != null)
        Problem(
          Severity.error,
          'invalid_op',
          'op-$i',
          'Операция ${i + 1} (${r.title}): ${r.error}',
        ),
    for (final MapEntry(key: i, value: keys) in outside.entries)
      Problem(
        Severity.error,
        'out_of_scope',
        'op-$i',
        'Операция ${i + 1} вне области: ${keys.join(', ')}',
      ),
    ...checkWorld(copy),
  ];
  final before = {for (final p in checkWorld(world)) _id(p)};
  return PlanPreview(copy, ops, outside, problems, [
    for (final p in problems)
      if (!before.contains(_id(p))) p,
  ]);
}
