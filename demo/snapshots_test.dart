// ПОКАЗ, а не проверка: рисует экраны мира на подменённой базе в PNG
// с настоящим шрифтом (иконки — квадратики). В check.sh не входит.
// Запуск: flutter test --no-pub demo/snapshots_test.dart  → снимки в build/snapshots/
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/content/location.dart';

import '../test/fakes.dart';

final _frame = GlobalKey();

Future<void> _loadFont() async {
  final bytes = File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final boundary =
        _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/snapshots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('содержимое мира по срезам', (t) async {
    await t.runAsync(_loadFont);
    t.view.physicalSize = const Size(400, 760);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final content = FakeContent();
    await pumpApp(t, content: content, wrap: _frame);
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await t.tap(find.text('Пепельные копи'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('new-location')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('location-title')), 'Штольня №3');
    await t.enterText(
      find.byKey(const Key('location-description')),
      'Затопленный нижний ярус, пахнет пеплом',
    );
    await _shot(t, '2.1-form');
    await t.tap(find.byKey(const Key('location-save')));
    await _shot(t, '2.1-world');

    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Ключ от лебёдки');
    await t.tap(find.byKey(const Key('item-kind-quest')));
    await t.enterText(find.byKey(const Key('item-level')), '2');
    await _shot(t, '2.2-form');
    await t.tap(find.byKey(const Key('item-save')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('new-item')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('item-title')), 'Кирка');
    await t.tap(find.byKey(const Key('item-rarity-rare')));
    await t.enterText(find.byKey(const Key('item-level')), '3');
    await t.enterText(find.byKey(const Key('item-stat')), '6');
    await t.enterText(find.byKey(const Key('item-price')), '40');
    await t.tap(find.byKey(const Key('item-save')));
    await _shot(t, '2.2-world');

    final saved = (await content.locations('0-Пепельные копи')).single;
    expect(saved, isA<Location>());
    // slug виден только здесь — в интерфейсе его нет.
    debugPrint('slug: ${saved.slug}');
    for (final i in await content.items('0-Пепельные копи')) {
      debugPrint('slug: ${i.slug}');
    }
  });
}
