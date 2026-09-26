// Настоящий Open5e (api.open5e.com/v2) — сеть. В check.sh НЕ входит. Запуск:
//   flutter test --no-pub live/open5e_live_test.dart
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_builder/open5e/open5e_api.dart';
import 'package:rpg_builder/open5e/open5e_import.dart';
import 'package:rpg_builder/check/world_check.dart';

void main() {
  test(
    'Open5e вживую: «pick» находит War Pick, он превращается в план',
    () async {
      final found = await const HttpOpen5e().searchItems('pick');
      final pick = found.firstWhere((o) => o.key == 'srd-2024_war-pick');
      expect(pick.damageDice, '1d8');
      final op = importPlan(pick, const WorldSnapshot()).ops.single;
      expect(op.fields['source_ref'], 'srd-2024_war-pick');
      // Магические предметы тоже ищутся (свой адрес /magicitems).
      expect(
        (await const HttpOpen5e().searchItems('healing'))
            .where((o) => o.rarity != null),
        isNotEmpty,
      );
    },
  );
}
