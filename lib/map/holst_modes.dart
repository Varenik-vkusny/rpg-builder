// Холст мира (5е): переключатель режимов внизу и палитра «Строить» — тащишь врага,
// жителя, событие, предмет или место прямо на холст.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'gesture_create.dart';
import 'holst_threads.dart' show dashed;

enum HolstMode { look, build, change }

/// Смотреть / Строить / Менять — цели 56 dp, выбранный — светлее и с чертой сверху.
class HolstModes extends StatelessWidget {
  const HolstModes({
    super.key,
    required this.mode,
    required this.onMode,
    this.modes = HolstMode.values,
  });

  final HolstMode mode;
  final ValueChanged<HolstMode> onMode;
  final List<HolstMode> modes;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: s.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final m in modes)
            Expanded(
              child: Semantics(
                selected: m == mode,
                button: true,
                child: InkWell(
                  key: Key('holst-mode-${m.name}'),
                  onTap: () => onMode(m),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    decoration: BoxDecoration(
                      color: m == mode ? s.surfaceContainerHigh : null,
                      border: Border(
                        top: BorderSide(
                          color: m == mode ? s.onSurface : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(switch (m) {
                          HolstMode.look => Symbols.visibility_rounded,
                          HolstMode.build => Symbols.pan_tool_rounded,
                          HolstMode.change => Symbols.auto_awesome_rounded,
                        }, color: m == mode ? s.onSurface : s.onSurfaceVariant),
                        Text(
                          switch (m) {
                            HolstMode.look => 'Смотреть',
                            HolstMode.build => 'Строить',
                            HolstMode.change => 'Менять',
                          },
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: m == mode ? s.onSurface : s.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData newIcon(NewKind k) => switch (k) {
  NewKind.enemy => Symbols.skull_rounded,
  NewKind.npc => Symbols.person_rounded,
  NewKind.event => Symbols.bolt_rounded,
  NewKind.item => Symbols.key_rounded,
  NewKind.place => Symbols.location_on_rounded,
};

String paletteName(NewKind k) => switch (k) {
  NewKind.enemy => 'Враг',
  NewKind.npc => 'Житель',
  NewKind.event => 'Событие',
  NewKind.item => 'Предмет',
  NewKind.place => 'Место',
};

/// Палитра: пять плиток с пунктиром — тащить на холст.
class HolstPalette extends StatelessWidget {
  const HolstPalette({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        spacing: 8,
        children: [
          for (final k in NewKind.values)
            Expanded(
              child: Draggable<NewKind>(
                key: Key('palette-${k.name}'),
                data: k,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Transform.translate(
                  offset: const Offset(-74, -34),
                  child: _Ghost(k),
                ),
                child: Semantics(
                  label: 'Перетащить на холст: ${paletteName(k)}',
                  child: CustomPaint(
                    painter: _DashedBox(s.outline),
                    child: SizedBox(
                      height: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            newIcon(k),
                            size: 20,
                            color: s.onSurfaceVariant,
                            fill: k == NewKind.event ? 1 : 0,
                          ),
                          FittedBox(
                            child: Text(
                              paletteName(k),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Пунктирная рамка плитки палитры: «это можно утащить».
class _DashedBox extends CustomPainter {
  const _DashedBox(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    dashed(Path()..addRect((Offset.zero & size).deflate(.5))),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke,
  );

  @override
  bool shouldRepaint(_DashedBox old) => old.color != color;
}

/// Призрак под пальцем: жетон с пунктиром «Новый враг».
class _Ghost extends StatelessWidget {
  const _Ghost(this.kind);

  final NewKind kind;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surfaceContainerHighest,
      shape: Border.all(color: s.onSurface, width: 2),
      child: SizedBox(
        width: 148,
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Icon(newIcon(kind), color: s.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                newTitle(kind),
                maxLines: 2,
                overflow: TextOverflow.clip,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
