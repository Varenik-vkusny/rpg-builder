// Снимки экранов для показа владельцу: рамка, шрифт, PNG в build/snapshots/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final frame = GlobalKey();

Future<void> loadFont() async {
  final bytes = File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync();
  final loader = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
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
