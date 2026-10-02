// Перетаскивание блока места (5а.4): долгое нажатие поднимает блок — щелчок, блок чуть крупнее
// и с тенью, — дальше он едет за пальцем; отпустил — положение уходит в раскладку.
// Короткое нажатие, как и раньше, открывает место.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BlockDrag extends StatefulWidget {
  const BlockDrag({
    super.key,
    required this.onStart,
    required this.onMove,
    required this.onDrop,
    required this.child,
  });

  final VoidCallback onStart;

  /// Смещение от точки, где блок подняли, — в единицах холста (масштаб уже учтён).
  final ValueChanged<Offset> onMove;
  final VoidCallback onDrop;
  final Widget child;

  @override
  State<BlockDrag> createState() => _BlockDragState();
}

class _BlockDragState extends State<BlockDrag> {
  bool _lifted = false;

  void _lift(bool v) => setState(() => _lifted = v);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPressStart: (_) {
      HapticFeedback.mediumImpact();
      _lift(true);
      widget.onStart();
    },
    onLongPressMoveUpdate: (d) => widget.onMove(d.localOffsetFromOrigin),
    onLongPressEnd: (_) {
      _lift(false);
      widget.onDrop();
    },
    child: AnimatedScale(
      scale: _lifted ? 1.06 : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          boxShadow: [
            if (_lifted)
              const BoxShadow(
                color: Color(0x99000000),
                offset: Offset(0, 10),
                blurRadius: 18,
              ),
          ],
        ),
        child: widget.child,
      ),
    ),
  );
}
