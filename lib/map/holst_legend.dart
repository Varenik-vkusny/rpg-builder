// Холст мира (5е): легенда в шторке «?» — цвета, рамки объектов, метки, жесты.
// Образцы рисуются тем же, чем холст (рамки — TokenFramePainter, стрелка — paintEdgeArrow).
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../help/help_texts.dart';
import '../ui/theme.dart';
import 'holst_tags.dart' show EdgeArrowSample;
import 'holst_threads.dart';
import 'token_frame.dart';

/// Значки первых трёх жестов — по порядку строк справки «holst».
const _gestureIcons = [
  Symbols.touch_app_rounded,
  Symbols.pinch_rounded,
  Symbols.south_east_rounded,
];

/// Жесты «Строить» — в легенде под строками справки.
const _buildGestures = [
  (Symbols.add_rounded, 'Из палитры в место — создать'),
  (Symbols.gesture_rounded, 'От объекта к объекту — связь'),
  (Symbols.pan_tool_rounded, 'Держать и тащить — перенести'),
  (Symbols.undo_rounded, 'Отменить — 5 секунд после жеста'),
];

/// Легенда в шторке «?»: цвета, метки, жесты (строки жестов — из справки «holst»).
List<Widget> holstLegend(BuildContext context, ScreenHelp help) {
  final s = Theme.of(context).colorScheme;
  final c = AppColors.of(context);
  Widget head(String t) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 1,
        fontWeight: FontWeight.w600,
        color: s.onSurfaceVariant,
      ),
    ),
  );
  Widget swatch(Color color, String label) => Row(
    children: [
      Container(width: 56, height: 24, color: color),
      const SizedBox(width: 10),
      Text(label),
    ],
  );
  final tones = threadColors(context);
  // Образец метки: как на холсте — плашка цвета связи со словами.
  Widget tag(ThreadTone tone, String word, String label) => Row(
    children: [
      SizedBox(
        width: 96,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            color: tones.of(tone),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tones.ink,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label)),
    ],
  );
  return [
    head('Цвета'),
    swatch(s.primary, 'Главное действие'),
    swatch(c.change, 'Изменено'),
    swatch(c.ok, 'Новое'),
    swatch(c.warn, 'Предупреждение'),
    swatch(s.error, 'Ошибка'),
    head('Объекты'),
    for (final (shape, label) in [
      (FrameShape.round, 'Житель'),
      (FrameShape.spiky, 'Враг'),
      (FrameShape.square, 'Предмет'),
    ])
      Row(
        children: [
          SizedBox(
            width: 56,
            height: 40,
            child: CustomPaint(
              key: Key('legend-frame-${shape.name}'),
              painter: TokenFramePainter(shape, s.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    head('Метки'),
    tag(ThreadTone.hot, 'убить ×3', 'Связь выбранного'),
    tag(ThreadTone.isNew, 'роняет 35%', 'Новая связь'),
    tag(ThreadTone.changed, 'пройти', 'Изменённая связь'),
    // Как на холсте: стрелка у края в сторону связанного (раньше тут был квадрат).
    Row(
      children: [
        SizedBox(
          width: 96,
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: CustomPaint(
              key: const Key('legend-edge-arrow'),
              size: const Size(28, 28),
              painter: EdgeArrowSample(tones.hot, tones.ink),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('Ещё связь — за краем')),
      ],
    ),
    // За дверью — как на холсте: квадратик цвета связи у верхнего края двери.
    Row(
      children: [
        SizedBox(
          width: 96,
          height: 28,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              key: const Key('legend-door-mark'),
              width: 40,
              height: 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: s.surfaceContainerHighest,
                        border: Border.all(color: s.outline),
                      ),
                      child: Icon(
                        Symbols.south_east_rounded,
                        size: 14,
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 0,
                    child: Container(width: 10, height: 10, color: tones.hot),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('Ещё связь — за дверью')),
      ],
    ),
    // Значки в покое на жетоне — откуда к нему связи (19.10), в легенде их не было.
    Row(
      children: [
        SizedBox(
          width: 96,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('legend-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: s.surfaceContainerHighest,
                border: Border.all(color: s.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.flag_rounded,
                    size: 12,
                    color: s.onSurfaceVariant,
                  ),
                  Text(
                    '1',
                    style: TextStyle(fontSize: 10, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('Значки — откуда связи')),
      ],
    ),
    head('Жесты'),
    for (final (icon, text) in [
      for (final (i, l) in help.lines.indexed)
        (_gestureIcons[i % _gestureIcons.length], l),
      ..._buildGestures,
    ])
      Row(
        children: [
          SizedBox(width: 56, child: Icon(icon, color: s.onSurfaceVariant)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
  ];
}
