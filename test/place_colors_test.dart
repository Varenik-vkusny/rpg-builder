// Правка 4 (29.09): свой цвет места — приглушённый и не похож на смысловые цвета
// (голубой — действие, пурпурный — изменено, красный — ошибка, жёлтый — предупреждение,
// зелёный — новое). Цвет выбирается по slug места (у мира — по id).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/ui/cover_card.dart';
import 'package:rpg_builder/ui/palettes.dart';

import 'assistant_fixtures.dart';
import 'fakes.dart';

/// Разница оттенков по кругу, 0–180°.
double hueGap(Color a, Color b) {
  final d = (HSVColor.fromColor(a).hue - HSVColor.fromColor(b).hue).abs();
  return d > 180 ? 360 - d : d;
}

/// Почему цвет не годится в цвет места; пусто — годится.
/// Порог 30°: коричневый между красным (0°) и жёлтым (~50°) не пройдёт ни с какой стороны.
List<String> problemsOf(Color c, Palette p) {
  final hsv = HSVColor.fromColor(c);
  final hex = c.toARGB32().toRadixString(16);
  final out = <String>[];
  if (hsv.saturation > .45) out.add('#$hex слишком яркий');
  // Настоящий серый (насыщенность < 0.08) — оттенка нет, спутать не с чем.
  if (hsv.saturation < .08) return out;
  for (final MapEntry(key: m, value: v) in {
    'голубой (действие)': p.primary,
    'пурпурный (изменено)': p.change,
    'красный (ошибка)': p.error,
    'жёлтый (предупреждение)': p.warn,
    'зелёный (новое)': p.ok,
  }.entries) {
    final gap = hueGap(c, v);
    if (gap < 30) out.add('#$hex похож на $m: разница ${gap.round()}°');
  }
  return out;
}

void main() {
  for (final (name, p) in [
    ('тёмная', darkPalette),
    ('светлая', lightPalette),
  ]) {
    test('цвета мест ($name): приглушённые и далеко от смысловых', () {
      final bad = [for (final c in p.coverHues) ...problemsOf(c, p)];
      expect(bad, isEmpty, reason: bad.join('\n'));
      expect(p.coverHues.length, greaterThanOrEqualTo(4));
    });
  }

  test('прибор ловит граничные цвета, а не только грубые', () {
    // Приглушённая умбра (~27°) — между ошибкой и предупреждением.
    expect(problemsOf(const Color(0xFFAE8A6C), darkPalette), isNotEmpty);
    // Серо-бирюзовый (~200°) рядом с голубым действием.
    expect(problemsOf(const Color(0xFF7A9EAE), darkPalette), isNotEmpty);
    // Тёплый серый с оттенком (насыщенность 0.10) не прячется за «серым».
    expect(problemsOf(const Color(0xFF9C948C), darkPalette), isNotEmpty);
  });

  testWidgets('экраны берут цвет по slug места, а не по названию', (t) async {
    await pumpApp(t, content: await minesContent());
    await signUp(t, 'author@test.dev');
    await createWorld(t, 'Пепельные копи');
    await openWorld(t, 'Пепельные копи');
    final inWorld = t.widget<CoverCard>(
      find.byKey(const Key('open-shtolnya_3')),
    );
    expect(inWorld.seed, 'shtolnya_3');

    await t.tap(find.byKey(const Key('open-shtolnya_3')));
    await t.pumpAndSettle();
    final onPage = t.widget<CoverCard>(find.byType(CoverCard));
    expect(onPage.seed, 'shtolnya_3');
  });
}
