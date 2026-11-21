// Порядок жетонов в месте — по времени создания, общий для жителей, врагов и событий
// (владелец 19.11: новое не двигает старое). Иначе событие, созданное раньше нового
// врага, после повторного входа уезжало под него: жители шли списком, события — следом.
import '../check/world_check.dart';
import 'holst_scene.dart' show HolstToken;

/// Когда создан каждый житель, враг и событие — только то, что уже в базе.
Map<String, DateTime> bornOf(WorldSnapshot w) => {
  for (final c in w.characters) c.id: ?c.createdAt,
  for (final e in w.events) e.id: ?e.createdAt,
};

/// [tokens] старые первыми: с временем — по нему, без времени (ещё не в базе) — в конце,
/// в прежнем порядке. Сортировка устойчивая: равные остаются как были.
List<HolstToken> byBirth(List<HolstToken> tokens, Map<String, DateTime> born) {
  final indexed = [...tokens.indexed];
  indexed.sort((a, b) {
    final ta = born[a.$2.id], tb = born[b.$2.id];
    if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
    if (ta != null && tb == null) return -1;
    if (ta == null && tb != null) return 1;
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, t) in indexed) t];
}
