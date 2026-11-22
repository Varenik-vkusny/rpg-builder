// Предмет на экране образцов: карточка «каким станет предмет» перед импортом — коротко,
// как у врага: название, оригинал, вид, редкость, цена, урон или защита, значок;
// плашками — только проблемы, которые принесёт сам импорт.
import 'package:flutter/material.dart';

import '../check/world_check.dart';
import '../content/item.dart';
import '../ui/parts.dart';
import '../content/world_pages.dart' show itemKindIcon;
import 'open5e_api.dart';
import 'open5e_import.dart';

/// Каким предмет придёт в мир под именем [title]; [problems] — что появится в мире
/// после импорта (не весь мир).
class ItemPreview extends StatelessWidget {
  const ItemPreview({
    super.key,
    required this.o,
    required this.title,
    required this.problems,
  });

  final Open5eItem o;
  final String title;
  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final kind = kindOf(o);
    Widget row(String label, String value) => Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(color: s.onSurfaceVariant)),
        ),
        Expanded(child: Text(value)),
      ],
    );
    return Column(
      key: const Key('open5e-item-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          children: [
            Icon(itemKindIcon(kind), size: 36, color: s.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (title != o.name) row('Оригинал', o.name),
        row('Вид', kind.label),
        row('Редкость', rarityOf(o).label),
        row('Цена', '${(o.cost ?? 0).round()} зол.'),
        if (kind == ItemKind.weapon)
          row('Урон', '${averageDamage(o.damageDice)}'),
        if (kind == ItemKind.armor) row('Защита', '${o.armorClass}'),
        for (final p in problems)
          NoticeBanner(
            p.severity == Severity.error ? Notice.error : Notice.warning,
            p.message,
          ),
      ],
    );
  }
}
