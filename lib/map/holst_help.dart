// Холст мира (5е), понятно без обучения: подсказка при первом входе (3 строки), «?» —
// легенда цветов, меток и жестов, пустой мир — три быстрых старта. Тексты — одно-два слова.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../help/help_texts.dart';
import '../ui/theme.dart';
import 'holst_threads.dart';
import 'token_frame.dart';

const _coachKey = 'holst-coach';

/// Видел ли автор подсказку первого входа. Хранилище недоступно — считаем «видел»:
/// лучше не показать подсказку, чем закрывать ею холст.
Future<bool> coachSeen() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(_coachKey) ?? false;
  } catch (_) {
    return true;
  }
}

Future<void> markCoachSeen() async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_coachKey, true);
  } catch (_) {}
}

/// Подсказка первого входа: три строки и «Понятно».
class HolstCoach extends StatelessWidget {
  const HolstCoach({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: s.surfaceContainerLowest.withValues(alpha: .72),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            key: const Key('holst-coach'),
            color: s.surfaceContainerHigh,
            shape: Border(top: BorderSide(color: s.outline)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Text(
                    'Холст мира',
                    style: TextStyle(
                      fontFamily: AppStyle.of(context).display,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const _Tip(
                    Symbols.touch_app_rounded,
                    'Нажми объект — увидишь связи',
                  ),
                  const _Tip(
                    Symbols.pinch_rounded,
                    'Два пальца — ближе, дальше',
                  ),
                  const _Tip(
                    Symbols.pan_tool_rounded,
                    '«Строить» — тащи и соединяй',
                  ),
                  FilledButton(
                    key: const Key('holst-coach-ok'),
                    onPressed: onDone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Понятно'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 32,
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
    ],
  );
}

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
    Row(
      children: [
        SizedBox(
          width: 96,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 10, height: 10, color: tones.hot),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('Ещё связь — за краем или за дверью')),
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

/// Пустой мир: первое место, попросить ассистента, справочник — позже.
class EmptyStarts extends StatelessWidget {
  const EmptyStarts({super.key, required this.onPlace, required this.onAsk});

  final VoidCallback onPlace;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget start(
      Key key,
      IconData icon,
      String title, {
      String? sub,
      VoidCallback? onTap,
      bool main = false,
    }) => Material(
      color: main ? s.primary : s.surfaceContainerLow,
      shape: Border.all(color: main ? s.primary : s.outline),
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: main ? s.onPrimary : s.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: main
                            ? s.onPrimary
                            : onTap == null
                            ? s.onSurfaceVariant
                            : s.onSurface,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: s.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      key: const Key('holst-empty'),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            'Пустой мир',
            style: TextStyle(
              fontFamily: AppStyle.of(context).display,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          start(
            const Key('holst-start-place'),
            Symbols.add_rounded,
            'Первое место',
            onTap: onPlace,
            main: true,
          ),
          start(
            const Key('holst-start-ask'),
            Symbols.auto_awesome_rounded,
            'Попросить ассистента',
            onTap: onAsk,
          ),
          start(
            const Key('holst-start-library'),
            Symbols.menu_book_rounded,
            'Из справочника',
            sub: 'позже',
          ),
        ],
      ),
    );
  }
}
