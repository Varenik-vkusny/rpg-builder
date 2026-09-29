// Настоящие шрифты в тестах: без них flutter test рисует всё квадратами одной ширины,
// и переполнение или разрыв слова не видны. Нужны снимкам (demo/) и прибору text_fit_test.
import 'dart:io';

import 'package:flutter/services.dart';

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
  // Шрифты направлений стиля из assets/fonts: Семейство-Вес.ttf.
  final families = <String, List<File>>{};
  for (final f in Directory('assets/fonts').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last.split('-').first;
    (families[name] ??= []).add(f);
  }
  for (final MapEntry(key: name, value: files) in families.entries) {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(read(f.path));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('$material/materialicons-regular.otf'))).load();
  await (FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  )..addFont(read('$symbols/lib/fonts/MaterialSymbolsRounded.ttf'))).load();
}
