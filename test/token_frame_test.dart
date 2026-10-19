// Прибор «тип объекта читается формой рамки» (5д, выбор владельца 19.10): житель — круг,
// враг — круг с зубцами, предмет — квадрат (и на полке); у события и квеста рамки нет.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/map/holst_scene.dart' show TokenKind;
import 'package:rpg_builder/map/token_frame.dart';

import 'holst_fixture.dart';

FrameShape? shapeOf(WidgetTester t, String slug) {
  final f = find.byKey(Key('frame-$slug'));
  if (f.evaluate().isEmpty) return null;
  return (t.widget<CustomPaint>(f).painter! as TokenFramePainter).shape;
}

void main() {
  testWidgets('форма рамки по типу объекта', (t) async {
    await pumpHolst(t, await ashMines(), size: const Size(1100, 800));
    expect(shapeOf(t, 'brigadir'), FrameShape.round);
    expect(shapeOf(t, 'slizen'), FrameShape.spiky);
    expect(shapeOf(t, 'kirka'), FrameShape.square);
    expect(shapeOf(t, 'klyuch_ot_lebedki'), FrameShape.square);
    expect(shapeOf(t, 'zasada'), isNull);
    expect(shapeOf(t, 'obval'), isNull);
  });

  test('три формы разные, у события и квеста рамки нет', () {
    expect(
      {for (final k in TokenKind.values) frameOf(k)},
      {FrameShape.round, FrameShape.spiky, FrameShape.square, null},
    );
  });
}
