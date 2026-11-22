// id новой строки даёт приложение (создание жестом и формой): тогда копия мира для
// проверки и запись в базу говорят об одном и том же объекте.
import 'dart:math';

final _rnd = Random.secure();

/// uuid версии 4 — id новой строки.
String newId() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
