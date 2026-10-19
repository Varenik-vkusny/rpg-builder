// Холст мира (5е): колёсико числа связи («Шанс» 5–100 %, «Сколько» 1–10) и короткое
// меню вида связи (квест → житель: «Поговорить / Убить»). Ширина — под палец, цели 48 dp.
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'gesture_link.dart';
import 'holst_threads.dart' show dashed;

/// Значения колёсика по виду.
List<int> wheelValues(Wheel w) => switch (w) {
  Wheel.chance => [for (var k = 1; k <= 20; k++) k * 5],
  Wheel.count => [for (var k = 1; k <= 10; k++) k],
  Wheel.none => const [],
};

/// С чего колёсико начинает: шанс — 25 %, сколько — 1.
int wheelStart(Wheel w) => w == Wheel.chance ? 25 : 1;

class NumberWheel extends StatefulWidget {
  const NumberWheel({
    super.key,
    required this.wheel,
    required this.onChanged,
    required this.onDone,
  });

  final Wheel wheel;
  final ValueChanged<int> onChanged;
  final VoidCallback onDone;

  @override
  State<NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<NumberWheel> {
  late final _values = wheelValues(widget.wheel);
  late int _cur = _values.indexOf(wheelStart(widget.wheel));
  late final _ctl = FixedExtentScrollController(initialItem: _cur);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _fmt(int v) => widget.wheel == Wheel.chance ? '$v%' : '×$v';

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      key: const Key('holst-wheel'),
      color: s.surfaceContainerHigh,
      shape: Border.all(color: s.outline),
      child: SizedBox(
        width: 150,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                widget.wheel == Wheel.chance ? 'Шанс' : 'Сколько',
                style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
              ),
            ),
            SizedBox(
              height: 144,
              // Барабан рисует строки и за своей рамкой — обрезать, иначе налезет на «Шанс».
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListWheelScrollView.useDelegate(
                        key: const Key('holst-wheel-drum'),
                        controller: _ctl,
                        itemExtent: 48,
                        physics: const FixedExtentScrollPhysics(),
                        // Плоский барабан: строки ровно в рамке, как в прототипе.
                        diameterRatio: 1000,
                        onSelectedItemChanged: (i) {
                          setState(() => _cur = i);
                          widget.onChanged(_values[i]);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _values.length,
                          builder: (_, i) => Center(
                            child: Text(
                              _fmt(_values[i]),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: i == _cur
                                    ? s.onSurface
                                    : s.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Рамка выбранной строки.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 48,
                      height: 48,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.symmetric(
                              horizontal: BorderSide(color: s.outline),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FilledButton(
              key: const Key('holst-wheel-done'),
              onPressed: widget.onDone,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: const RoundedRectangleBorder(),
              ),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Меню вида связи: «Обвал → Бригадир», «Поговорить», «Убить».
class LinkMenu extends StatelessWidget {
  const LinkMenu({super.key, required this.title, required this.onPick});

  final String title;
  final ValueChanged<LinkKind> onPick;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    Widget item(LinkKind k, IconData icon, String text) => InkWell(
      key: Key('holst-menu-${k.name}'),
      onTap: () => onPick(k),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: s.outlineVariant)),
        ),
        child: Row(
          children: [
            Icon(icon, color: s.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      key: const Key('holst-menu'),
      color: s.surfaceContainerHigh,
      shape: Border.all(color: s.outline),
      child: SizedBox(
        width: 200,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                title,
                style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
              ),
            ),
            item(LinkKind.talk, Symbols.forum_rounded, 'Поговорить'),
            item(LinkKind.kill, Symbols.swords_rounded, 'Убить'),
          ],
        ),
      ),
    );
  }
}

/// Нить под пальцем, пока её тянут: пунктир от объекта до пальца.
class TempLine extends CustomPainter {
  const TempLine({required this.from, required this.to, required this.color});

  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    dashed(
      Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy),
    ),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  @override
  bool shouldRepaint(TempLine old) => old.from != from || old.to != to;
}
