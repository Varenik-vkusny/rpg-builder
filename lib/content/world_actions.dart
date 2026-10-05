import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// История, проверка и экспорт — значками в шапке мира.
List<Widget> worldActions({
  required VoidCallback onHistory,
  required VoidCallback onCheck,
  required VoidCallback onExport,
}) => [
  IconButton(
    key: const Key('history-open'),
    tooltip: 'История изменений',
    icon: const Icon(Symbols.history_rounded),
    onPressed: onHistory,
  ),
  IconButton(
    key: const Key('check-world'),
    tooltip: 'Проверка мира',
    icon: const Icon(Symbols.fact_check_rounded),
    onPressed: onCheck,
  ),
  IconButton(
    key: const Key('world-export'),
    tooltip: 'Экспорт в JSON',
    icon: const Icon(Symbols.ios_share_rounded),
    onPressed: onExport,
  ),
];
