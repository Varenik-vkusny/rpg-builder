// Снимки экранов для показа владельцу: рамка, шрифт, PNG в build/snapshots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final frame = GlobalKey();

/// Шрифты как на Android: Roboto и оба шрифта значков — иначе на снимке квадраты.
Future<void> loadFont() async {
  var dir = File(Platform.resolvedExecutable).parent;
  while (!Directory('${dir.path}/material_fonts').existsSync()) {
    dir = dir.parent;
  }
  final material = '${dir.path}/material_fonts';
  final pubCache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['LOCALAPPDATA']}/Pub/Cache';
  final symbols = Directory('$pubCache/hosted/pub.dev')
      .listSync()
      .firstWhere((d) => d.path.contains('material_symbols_icons-'))
      .path;
  Future<ByteData> read(String path) async =>
      ByteData.sublistView(File(path).readAsBytesSync());
  await (FontLoader('Roboto')
        ..addFont(read('$material/roboto-regular.ttf'))
        ..addFont(read('$material/roboto-medium.ttf'))
        ..addFont(read('$material/roboto-bold.ttf')))
      .load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('$material/materialicons-regular.otf'))).load();
  await (FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  )..addFont(read('$symbols/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
}

Future<void> shot(WidgetTester t, String name) async {
  await t.pumpAndSettle();
  await t.runAsync(() async {
    final boundary =
        frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/snapshots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> tapShown(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Открывает выпадающий список и выбирает вариант.
Future<void> pick(WidgetTester t, String key, String option) async {
  await tapShown(t, find.byKey(Key(key)));
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}
