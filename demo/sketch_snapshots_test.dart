// ПОКАЗ, а не проверка: скетч на экране ассистента — выбор «камера / галерея», фото приложено,
// план «создать персонажа». Камера подменена рисунком test/fixtures/sketch_merchant.png.
// Запуск: flutter test --no-pub demo/sketch_snapshots_test.dart → build/snapshots/sketch-*.png
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:rpg_builder/assistant/plan.dart';

import '../test/assistant_fixtures.dart';
import '../test/fakes.dart';
import 'shots.dart';

class _Picker extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(
    File('test/fixtures/sketch_merchant.png').readAsBytesSync(),
    name: 'sketch.png',
    mimeType: 'image/png',
  );
}

void main() {
  testWidgets('скетч на экране ассистента', (t) async {
    await t.runAsync(loadFont);
    final previous = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _Picker();
    addTearDown(() => ImagePickerPlatform.instance = previous);
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final plan = Plan.fromJson({
      'summary': 'Создать торговку Лампщицу Мирру в Штольне №3',
      'ops': [
        {
          'action': 'create',
          'type': 'character',
          'slug': 'lampshchitsa_mirra',
          'fields': {
            'title': 'Лампщица Мирра',
            'description': 'Торгует лампами и маслом в штольне',
            'role': 'merchant',
            'level': 3,
            'hp': 15,
            'attack': 2,
            'location': 'shtolnya_3',
          },
        },
      ],
    });
    await pumpApp(
      t,
      content: await minesContent(),
      assistant: FakeAssistant([proposal(plan)]),
      wrap: frame,
    );
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    await tapShown(t, find.byKey(const Key('assistant-open')));
    await pick(t, 'scope-object-location', 'Штольня №3');

    await tapShown(t, find.byKey(const Key('sketch-attach')));
    await shot(t, 'sketch-1-source');
    await tapShown(t, find.byKey(const Key('sketch-camera')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await shot(t, 'sketch-2-attached');

    await tapShown(t, find.byKey(const Key('assistant-propose')));
    await shot(t, 'sketch-3-plan');
  });
}
