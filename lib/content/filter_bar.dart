import 'package:flutter/material.dart';

/// Полоска фильтров-чипов (4.3): выбранные — подсвечены, ничего не выбрано — все.
/// Ключ чипа — `filter-<prefix>-<значение>`.
class FilterBar<T extends Enum> extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.prefix,
    required this.values,
    required this.label,
    required this.selected,
    required this.onToggle,
  });

  final String prefix;
  final List<T> values;
  final String Function(T) label;
  final Set<T> selected;
  final void Function(T) onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final v in values)
          FilterChip(
            key: Key('filter-$prefix-${v.name}'),
            label: Text(label(v)),
            selected: selected.contains(v),
            onSelected: (_) => onToggle(v),
          ),
      ],
    ),
  );
}
