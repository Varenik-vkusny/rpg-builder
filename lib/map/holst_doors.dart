// Холст мира (5е): дверь — вложенное место внутри места — и клетка «ещё N».
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../ui/theme.dart';
import 'holst_parts.dart';
import 'holst_scene.dart';

/// Дверь — место внутри места: стопка карточек цвета вложенного места, кто внутри,
/// угловая кнопка «войти» 48 × 48.
class DoorTile extends StatelessWidget {
  const DoorTile({
    super.key,
    required this.door,
    required this.onEnter,
    this.mark,
    this.drop = false,
  });

  final HolstDoor door;
  final VoidCallback onEnter;

  /// «внутри 3 изменения» — план меняет что-то уровнем ниже.
  final String? mark;
  final bool drop;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final hue = placeHue(context, door.place);
    Color tint(double a) =>
        Color.alphaBlend(hue.withValues(alpha: a), s.surface);
    final inside = door.inside.isEmpty ? 'пусто' : door.inside.join(', ');
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: tokenTextScaleMax,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            top: 10,
            right: -10,
            bottom: -10,
            child: ColoredBox(color: tint(.08)),
          ),
          Positioned(
            left: 5,
            top: 5,
            right: -5,
            bottom: -5,
            child: ColoredBox(color: tint(.12)),
          ),
          Container(
            width: door.rect.width,
            height: door.rect.height,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tint(.22),
              border: drop ? Border.all(color: s.onSurface, width: 2) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.location_on_rounded,
                      size: 20,
                      color: s.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        door.place.title,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: mark != null
                      ? _DoorMark(mark!)
                      : Text(
                          'внутри: $inside',
                          maxLines: 2,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: s.onSurfaceVariant,
                          ),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: 'Войти в место ${door.place.title}',
              child: InkWell(
                key: Key('henter-${door.place.slug}'),
                onTap: onEnter,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Symbols.south_east_rounded, color: s.onSurface),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoorMark extends StatelessWidget {
  const _DoorMark(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(border: Border.all(color: c.change)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c.change,
        ),
      ),
    );
  }
}

/// Клетка «ещё N»: что не влезло в место, не спрятано молча.
class OverflowTile extends StatelessWidget {
  const OverflowTile({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      width: tokenSize.width,
      height: tokenSize.height,
      decoration: BoxDecoration(border: Border.all(color: s.outline)),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.add_rounded, size: 20, color: s.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'ещё $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: s.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
