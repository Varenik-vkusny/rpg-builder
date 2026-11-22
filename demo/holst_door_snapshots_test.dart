// ПОКАЗ (С9, 22.11): подпись двери «внутри: …» — было (две строки, обрыв на запятой) и
// стало (имена целиком, «· ещё N»). В check.sh не входит.
// Запуск: flutter test --no-pub demo/holst_door_snapshots_test.dart → build/snapshots/door-*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/location.dart';
import 'package:rpg_builder/map/door_inside.dart';
import 'package:rpg_builder/map/holst_doors.dart';
import 'package:rpg_builder/map/holst_scene.dart';
import 'package:rpg_builder/ui/theme.dart';

import 'shots.dart';

const _zaboy = Location(
  id: 'z',
  slug: 'zaboy',
  title: 'Забой',
  description: '',
  levelMin: 1,
  levelMax: 3,
);

void main() {
  testWidgets('двери: было и стало', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const cases = [
      ['Слизень', 'Засада'],
      ['Слизень', 'Засада', 'Камнеед'],
      ['Слизень', 'Засада', 'Камнеед', 'Гоблин-разведчик', 'Страж'],
    ];
    final small = TextStyle(fontSize: 12, height: 1.3, color: Colors.grey[400]);
    await t.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final names in cases) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 92,
                          height: 34,
                          child: Text(
                            'внутри: ${names.join(', ')}',
                            maxLines: 2,
                            overflow: TextOverflow.clip,
                            style: small,
                          ),
                        ),
                        const SizedBox(width: 24),
                        DoorTile(
                          door: HolstDoor(
                            _zaboy,
                            const Rect.fromLTWH(0, 0, 148, 104),
                            names,
                          ),
                          onEnter: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                  SizedBox(
                    width: 92,
                    child: DoorInside(names: cases[0], style: small),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await shot(t, 'door-1-before-after', ratio: 3);
  });
}
