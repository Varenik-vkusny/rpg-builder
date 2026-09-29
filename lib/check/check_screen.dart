import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../assistant/assistant_screen.dart';
import '../assistant/assistant_service.dart';
import '../assistant/scope.dart';
import '../content/content_repo.dart';
import '../worlds/world.dart';
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
        appBar: AppBar(title: const Text('Проверка мира')),
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
            final problems = checkWorld(snap.data!);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                _summary(problems),
                const SizedBox(height: 16),
                for (final (i, p) in problems.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ProblemRow(
                      p,
                      fixKey: Key('fix-$i'),
                      onFix: () => _fix(snap.data!, p),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Итог сверху: «Проблем не найдено» или число ошибок и предупреждений.
  Widget _summary(List<Problem> problems) {
    final s = Theme.of(context).colorScheme;
    final c = AppColors.of(context);
    int count(Severity v) => problems.where((p) => p.severity == v).length;
    final errors = count(Severity.error);
    // Чистый мир — спокойная строка обычным цветом, без зелёной плашки (владелец 28.09).
    final (bg, fg, icon) = problems.isEmpty
        ? (s.surfaceContainerLow, s.onSurface, Symbols.task_alt_rounded)
        : errors > 0
        ? (s.errorContainer, s.onErrorContainer, Symbols.error_rounded)
        : (c.warnContainer, c.onWarnContainer, Symbols.warning_rounded);
    return Card(
      color: bg,
      child: ListTile(
        key: const Key('check-summary'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(icon, color: fg, fill: 1, size: 32),
        title: Text(widget.world.title, style: TextStyle(color: fg)),
        subtitle: Text(
          problems.isEmpty
              ? 'Проблем не найдено'
              : 'Ошибок: $errors · '
                    'Предупреждений: ${count(Severity.warning)}',
          style: TextStyle(
            color: fg,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Проблема мира: значок и слово «Ошибка» / «Предупреждение», текст, «Исправить».
class ProblemRow extends StatelessWidget {
  const ProblemRow(this.problem, {super.key, required this.onFix, this.fixKey});
  final Problem problem;
  final VoidCallback onFix;
  final Key? fixKey;

  static IconData iconOf(Severity s) =>
      s == Severity.error ? Symbols.error_rounded : Symbols.warning_rounded;

  @override
  Widget build(BuildContext context) {
    final error = problem.severity == Severity.error;
    final tint = error
        ? Theme.of(context).colorScheme.error
        : AppColors.of(context).warn;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        leading: Icon(iconOf(problem.severity), color: tint, fill: 1),
        title: Text(problem.message),
        // Кнопка — под текстом справа: рядом с текстом она зажимала его до разрыва слов.
        // Не влезает рядом со словом (крупный шрифт) — переходит на строку ниже.
        subtitle: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            Text(
              problem.severity.label,
              style: TextStyle(color: tint, fontWeight: FontWeight.w500),
            ),
            FilledButton.tonal(
              key: fixKey,
              // Высота из темы — 48 dp, минимум касания на Android (было 40).
              onPressed: onFix,
              child: const Text('Исправить'),
            ),
          ],
        ),
      ),
    );
  }
}
