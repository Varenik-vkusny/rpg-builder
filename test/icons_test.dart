// Прибор 5.3: все значки — из одного набора (Material Symbols, скруглённые).
// Старый Icons.* рисует другим весом и формой — в интерфейсе видна разнобойность.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('значки только из Symbols: ни одного Icons.* в lib/', () {
    final found = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          for (final (i, line) in f.readAsLinesSync().indexed)
            if (RegExp(r'\bIcons\.').hasMatch(line)) '${f.path}:${i + 1}',
    ];
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
