import 'package:flutter/material.dart';

import '../help/help.dart';
import '../assistant/assistant_screen.dart';
import '../assistant/assistant_service.dart';
import '../assistant/scope.dart';
import '../content/content_repo.dart';
import '../worlds/world.dart';
import '../ui/check_cells.dart';
import '../ui/theme.dart';
import 'world_check.dart';

/// «Проверка мира»: все ошибки и предупреждения мира одним списком.
/// У каждой проблемы — «Исправить»: ассистент с областью и просьбой (3.8).
/// Закрывается с true, если мир менялся (исправление применили).
class CheckScreen extends StatefulWidget {
  const CheckScreen({
    super.key,
    required this.world,
    required this.repo,
    required this.assistant,
  });

  final World world;
  final ContentRepo repo;
  final AssistantService assistant;

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  late Future<WorldSnapshot> _world = _load();
  bool _changed = false;

  Future<WorldSnapshot> _load() => widget.repo.snapshot(widget.world.id);

  /// Ассистент на этой проблеме: область — объект проблемы (или связанный с ним),
  /// просьба — сама проблема. Применили — перечитать проверку.
  Future<void> _fix(WorldSnapshot w, Problem p) async {
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssistantScreen(
          world: widget.world,
          snapshot: w,
          assistant: widget.assistant,
          repo: widget.repo,
          initialScope: scopeForObject(w, p.objectId),
          initialRequest: 'Исправь проблему проверки мира: ${p.message}',
        ),
      ),
    );
    if (applied == true) {
      _changed = true;
      setState(() {
        _world = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Проверка мира'),
          actions: const [HelpAction('check')],
        ),
        body: FutureBuilder<WorldSnapshot>(
          future: _world,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text('Не удалось загрузить мир: ${snap.error}'),
              );
            }
            return _list(snap.data!, checkWorld(snap.data!));
          },
        ),
      ),
    );
  }

  Widget _list(WorldSnapshot w, List<Problem> problems) {
    final errors = problems.where((p) => p.severity == Severity.error);
    final warns = problems.where((p) => p.severity == Severity.warning);
    Widget section(String title, Iterable<Problem> ps) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final p in ps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ProblemRow(
              p,
              fixKey: Key('fix-${problems.indexOf(p)}'),
              onFix: () => _fix(w, p),
            ),
          ),
      ],
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        CheckStrip(
          key: const Key('check-summary'),
          errors: errors.length,
          warnings: warns.length,
          big: true,
        ),
        if (errors.isNotEmpty) section('Ошибки', errors),
        if (warns.isNotEmpty) section('Предупреждения', warns),
      ],
    );
  }
}

/// Проблема мира: ячейка цвета тяжести со значком слева; справа текст, слово
/// «Ошибка» / «Предупреждение» цветом и «Исправить».
class ProblemRow extends StatelessWidget {
  const ProblemRow(this.problem, {super.key, required this.onFix, this.fixKey});
  final Problem problem;
  final VoidCallback onFix;
  final Key? fixKey;

  @override
  Widget build(BuildContext context) {
    final tint = problem.severity == Severity.error
        ? Theme.of(context).colorScheme.error
        : AppColors.of(context).warn;
    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SeverityCell(problem.severity),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(problem.message, style: const TextStyle(fontSize: 15)),
                    // Как в прототипе: слово слева, «Исправить» прижата вправо (было:
                    // кнопка липла к слову, 26.11). Перенос — на всю ширину карточки;
                    // крупный шрифт и не влезает — кнопка уходит под слово, слово целое.
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          Text(
                            problem.severity.label,
                            style: TextStyle(
                              color: tint,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          FilledButton.tonal(
                            key: fixKey,
                            // Высота из темы — 48 dp, минимум касания на Android.
                            onPressed: onFix,
                            child: const Text('Исправить'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
