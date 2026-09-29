// Скетч (4.4): автор снимает рисунок камерой — фото уходит ассистенту с просьбой,
// план «создать персонажа» проверяется на копии и применяется. Камера подменена.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:rpg_builder/assistant/plan.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

/// 1×1 PNG — настоящая картинка, чтобы превью смогло её показать.
final sketchPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Камера и галерея: отдают [sketchPng] и запоминают, откуда просили.
class FakePicker extends ImagePickerPlatform {
  final sources = <ImageSource>[];

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    sources.add(source);
    return XFile.fromData(sketchPng, name: 'sketch.png', mimeType: 'image/png');
  }
}

/// План по скетчу: новый житель в Штольне №3.
Plan foremanPlan() => Plan.fromJson({
  'summary': 'Бригадир Грум по скетчу',
  'ops': [
    {
      'action': 'create',
      'type': 'character',
      'slug': 'brigadir_grum',
      'fields': {
        'title': 'Бригадир Грум',
        'description': 'Каска, кирка на плече, борода лопатой',
        'role': 'npc',
        'level': 3,
        'hp': 20,
        'attack': 4,
        'location': 'shtolnya_3',
      },
    },
  ],
});

Future<FakePicker> usePicker() async {
  final previous = ImagePickerPlatform.instance;
  final picker = FakePicker();
  ImagePickerPlatform.instance = picker;
  addTearDown(() => ImagePickerPlatform.instance = previous);
  return picker;
}

/// Штольня №3 областью, фото скетча с камеры.
Future<void> attachFromCamera(WidgetTester t) async {
  await t.tap(find.byKey(const Key('scope-object-location')));
  await t.pumpAndSettle();
  await t.tap(find.text('Штольня №3').last);
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('sketch-attach')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('sketch-camera')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'скетч: фото с камеры уходит с просьбой, план создаёт персонажа — применить',
    (t) async {
      final picker = await usePicker();
      final (content, assistant) = await openAssistant(
        t,
        FakeAssistant([proposal(foremanPlan())]),
      );
      await attachFromCamera(t);

      expect(picker.sources, [ImageSource.camera]);
      expect(find.byKey(const Key('sketch-thumb')), findsOneWidget);
      // Пустая просьба заполняется сама — автор может её поправить.
      expect(find.text('Создай персонажа по этому скетчу'), findsOneWidget);

      await t.tap(find.byKey(const Key('assistant-propose')));
      await t.pumpAndSettle();
      final sent = assistant.requests.single;
      expect(sent.image?.bytes, sketchPng);
      expect(sent.image?.mime, 'image/png');
      expect(sent.toJson()['image'], {'mime': 'image/png', 'data': isNotEmpty});

      expectOp('Создать · Персонаж «Бригадир Грум»', 'Бригадир Грум');
      await t.tap(find.byKey(const Key('plan-apply')));
      await t.pumpAndSettle();
      final made = (await content.characters(minesId))
          .where((c) => c.slug == 'brigadir_grum')
          .single;
      expect(made.title, 'Бригадир Грум');
    },
  );

  testWidgets(
    'скетч: убранное фото не уходит; без фото в запросе нет картинки',
    (t) async {
      await usePicker();
      final (_, assistant) = await openAssistant(
        t,
        FakeAssistant([proposal(foremanPlan())]),
      );
      await attachFromCamera(t);
      await t.tap(find.byKey(const Key('sketch-remove')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sketch-thumb')), findsNothing);

      await t.tap(find.byKey(const Key('assistant-propose')));
      await t.pumpAndSettle();
      expect(assistant.requests.single.image, isNull);
      expect(assistant.requests.single.toJson().containsKey('image'), isFalse);
    },
  );
  testWidgets(
    'скетч: исправления плана уходят без фото — лимит модели со зрением не тратится',
    (t) async {
      await usePicker();
      // План с атакой 14 при потолке: проверка на копии ловит — ассистент исправляет дважды.
      final (_, assistant) = await openAssistant(t);
      await attachFromCamera(t);
      await t.tap(find.byKey(const Key('assistant-propose')));
      await t.pumpAndSettle();
      expect(assistant.requests, hasLength(3));
      expect(assistant.requests.first.image, isNotNull);
      expect(
        [for (final r in assistant.requests.skip(1)) r.image],
        [null, null],
      );
    },
  );
}
