// ПОКАЗ, а не проверка: имена жетонов с дефисом, длинным словом и без — не рвутся посреди слова.
// Запуск: flutter test --no-pub demo/token_name_snapshots_test.dart → build/snapshots/token-name.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/holst_parts.dart';
import 'package:rpg_builder/map/holst_scene.dart';
import 'package:rpg_builder/ui/theme.dart';

import 'shots.dart';

void main() {
  testWidgets('имена жетонов', (t) async {
    await t.runAsync(loadFont);
    const names = [
      ('Гоблин‑страж', TokenKind.enemy),
      ('Гоблин-разведчик', TokenKind.enemy),
      ('Старый бригадир', TokenKind.npc),
      ('Кирка', TokenKind.item),
      ('Трёхголовыйкрокодилосаврусище', TokenKind.npc),
    ];
    await t.binding.setSurfaceSize(const Size(200, 330));
    await t.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.dark),
        home: RepaintBoundary(
          key: frame,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                spacing: 12,
                children: [
                  for (final (n, k) in names)
                    TokenTile(
                      token: HolstToken(id: n, slug: n, kind: k, title: n),
                      hue: null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await shot(t, 'token-name', ratio: 3);
  });
}
