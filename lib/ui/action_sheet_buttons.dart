// Кнопки шторки вида А: «Отмена» рамкой, главная в виде риска (≥ 52 dp) и красная
// корзина в шапке форм. Шторка — action_sheet.dart.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Вид главной кнопки, если он не следует из риска шторки.
enum SheetMain { danger, dangerOutline, primary, plain }

/// «Отмена» — рамкой; закрывает шторку с [result].
Widget sheetCancel(
  BuildContext context,
  String label,
  Key key,
  Object? result,
) => OutlinedButton(
  key: key,
  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
  onPressed: () => Navigator.of(context).pop(result),
  child: Text(label),
);

/// Главная кнопка шторки в нужном виде.
Widget sheetMain(
  BuildContext context, {
  required String label,
  required SheetMain style,
  required Key key,
  required VoidCallback? onPressed,
  IconData? icon,
}) {
  final s = Theme.of(context).colorScheme;
  const size = Size(0, 52);
  final child = icon == null
      ? Text(label)
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Icon(icon, size: 20),
            Flexible(child: Text(label)),
          ],
        );
  return switch (style) {
    SheetMain.dangerOutline => OutlinedButton(
      key: key,
      style: OutlinedButton.styleFrom(
        minimumSize: size,
        foregroundColor: s.error,
        side: BorderSide(color: s.error, width: 2),
      ),
      onPressed: onPressed,
      child: child,
    ),
    _ => FilledButton(
      key: key,
      style: FilledButton.styleFrom(
        minimumSize: size,
        backgroundColor: switch (style) {
          SheetMain.danger => s.error,
          SheetMain.plain => s.onSurface,
          _ => s.primary,
        },
        foregroundColor: switch (style) {
          SheetMain.danger => s.onError,
          SheetMain.plain => s.surface,
          _ => s.onPrimary,
        },
      ),
      onPressed: onPressed,
      child: child,
    ),
  };
}

/// Корзина в шапке формы: красная и отделена чертой от «?» — чтобы не промахнуться.
class DeleteAction extends StatelessWidget {
  const DeleteAction({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: s.outlineVariant)),
      ),
      child: IconButton(
        key: const Key('object-delete'),
        tooltip: 'Удалить',
        color: s.error,
        icon: const Icon(Symbols.delete_rounded),
        onPressed: onPressed,
      ),
    );
  }
}
