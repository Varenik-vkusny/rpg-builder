import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'character.dart';
import 'filters.dart';
import 'item.dart';

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

/// Кнопка «Фильтр» раздела: сколько выбрано, по нажатию — чипы.
/// Ключ кнопки — `filter-<section>`.
class FilterToggle extends StatelessWidget {
  const FilterToggle({
    super.key,
    required this.section,
    required this.active,
    required this.onPressed,
  });

  final String section;
  final int active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: Key('filter-$section'),
      icon: const Icon(Symbols.filter_list_rounded),
      label: Text(active == 0 ? 'Фильтр' : 'Фильтр: $active'),
      onPressed: onPressed,
    ),
  );
}

/// Чипы фильтра предметов: редкость и вид.
List<Widget> itemFilters(ContentFilter f, ValueChanged<ContentFilter> set) => [
  FilterBar(
    prefix: 'rarity',
    values: Rarity.values,
    label: (r) => r.label,
    selected: f.rarities,
    onToggle: (r) =>
        set(f.copyWith(rarities: ContentFilter.toggle(f.rarities, r))),
  ),
  const SizedBox(height: 4),
  FilterBar(
    prefix: 'kind',
    values: ItemKind.values,
    label: (k) => k.label,
    selected: f.kinds,
    onToggle: (k) => set(f.copyWith(kinds: ContentFilter.toggle(f.kinds, k))),
  ),
];

/// Чипы фильтра персонажей по роли.
Widget roleFilter(ContentFilter f, ValueChanged<ContentFilter> set) =>
    FilterBar(
      prefix: 'role',
      values: Role.values,
      label: (r) => r.label,
      selected: f.roles,
      onToggle: (r) => set(f.copyWith(roles: ContentFilter.toggle(f.roles, r))),
    );
