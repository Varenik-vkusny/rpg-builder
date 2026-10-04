import 'package:flutter/material.dart';

/// Горизонтальная лента карточек.
class Rail extends StatelessWidget {
  const Rail(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 156,
    // Карточки узкие и лента фиксированной высоты: шрифт телефона растёт в них только
    // до ×1.15 — иначе слово рвётся, а название в две строки вылезает за карточку.
    child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => children[i],
      ),
    ),
  );
}
