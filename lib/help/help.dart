// Справка: «?» у поля формы и в шапке экрана, по нажатию — шторка снизу.
// На экране текста не прибавляется; сами тексты — в help_texts.dart.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'help_texts.dart';

/// Поле формы с «?» в правом верхнем углу. Значок лежит поверх поля и разметку не двигает.
class HelpField extends StatelessWidget {
  const HelpField(this.id, {super.key, required this.child});

  /// Ключ текста в [fieldHelp].
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final help = fieldHelp[id];
    assert(help != null, 'Нет текста справки для поля «$id»');
    if (help == null) return child;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: 'Справка: ${help.title}',
            excludeSemantics: true,
            child: InkResponse(
              key: Key('help-$id'),
              radius: 20,
              onTap: () => _sheet(context, help.title, [
                Text(help.what),
                _Example(help.example),
              ]),
              child: SizedBox(
                width: 44,
                height: 32,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Symbols.help_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `поле.help('ключ')` — то же, что [HelpField], без лишней вложенности в форме.
extension HelpFieldX on Widget {
  Widget help(String id) => HelpField(id, child: this);
}

/// «?» в шапке экрана.
class HelpAction extends StatelessWidget {
  const HelpAction(this.id, {super.key});

  /// Ключ текста в [screenHelp].
  final String id;

  @override
  Widget build(BuildContext context) {
    final help = screenHelp[id];
    assert(help != null, 'Нет текста справки для экрана «$id»');
    if (help == null) return const SizedBox.shrink();
    return IconButton(
      key: Key('help-screen-$id'),
      tooltip: 'Справка',
      icon: const Icon(Symbols.help_rounded),
      onPressed: () =>
          _sheet(context, help.title, [for (final l in help.lines) Text(l)]),
    );
  }
}

Future<void> _sheet(BuildContext context, String title, List<Widget> body) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('help-sheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 15, height: 1.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                ...body,
              ],
            ),
          ),
        ),
      ),
    );

/// Пример — ячейкой с рамкой и словом «ПРИМЕР», как «БЫЛО / СТАЛО» в плане.
class _Example extends StatelessWidget {
  const _Example(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: s.outline)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'ПРИМЕР',
              style: TextStyle(
                color: s.outline,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                letterSpacing: .4,
                height: 1.8,
              ),
            ),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
