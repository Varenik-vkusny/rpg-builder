// ПОКАЗ, а не проверка: экспорт мира (4.5) на подменённой базе.
// Запуск: flutter test --no-pub demo/export_snapshots_test.dart
//   → build/snapshots/4.5-*.png и сам файл build/export/pepelnye_kopi.json
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/character.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import '../test/world_export_test.dart' show FakeShare;
import 'shots.dart';

void main() {
  SharePlatform.instance = FakeShare.instance;

  testWidgets('экспорт: кнопка, предупреждение об ошибке, файл', (t) async {
    await t.runAsync(loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = await minesContent();
    await content.createCharacter(
      minesId,
      const NewCharacter(
        title: 'Призрак',
        description: '',
        role: Role.npc,
        locationId: 'loc-нет',
      ),
    );
    await pumpApp(t, content: content, assistant: FakeAssistant(), wrap: frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await t.longPress(find.byKey(const Key('world-export')));
    await shot(t, '4.5-export-button');
    await t.pump(const Duration(seconds: 5));

    await tapShown(t, find.byKey(const Key('world-export')));
    await shot(t, '4.5-export-errors');
    await tapShown(t, find.byKey(const Key('export-anyway')));

    final file = FakeShare.instance.shared.single.files!.single;
    final json = await t.runAsync(file.readAsString);
    File('build/export/pepelnye_kopi.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(json!);
  });
}
