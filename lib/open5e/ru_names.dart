// Русские названия справочника (5д, решение владельца 23.10): словарь лежит в приложении,
// а не переводится сервером — бесплатные модели отвечали 10–20 с и путали («кирка» →
// «pick, miner's»). Только SRD 5.1 и 5.2; у сторонних книг Open5e названия английские.
import 'dart:convert';

import 'package:flutter/services.dart';

class RuNames {
  const RuNames({required this.creatures, required this.items});

  /// Ключ образца Open5e (`srd_skeleton`) → русское название.
  final Map<String, String> creatures;
  final Map<String, String> items;

  static const empty = RuNames(creatures: {}, items: {});
  static const asset = 'assets/open5e_ru.json';

  static Future<RuNames> load([AssetBundle? bundle]) async {
    // Байтами, а не loadString: тот файлы больше 50 КБ разбирает в отдельном потоке.
    final bytes = await (bundle ?? rootBundle).load(asset);
    final j = jsonDecode(
      utf8.decode(bytes.buffer.asUint8List()),
    ) as Map<String, dynamic>;
    Map<String, String> part(String k) => (j[k] as Map).cast<String, String>();
    return RuNames(creatures: part('creatures'), items: part('items'));
  }

  String? of(String key) => creatures[key] ?? items[key];

  /// Ключи образцов, чьё русское название содержит [query] (без учёта регистра и «ё»):
  /// сначала начинающиеся с запроса, потом короткие. Не больше [limit].
  List<String> match(String query, {required bool creatures, int limit = 20}) {
    final q = _norm(query.trim());
    if (q.isEmpty) return const [];
    final names = creatures ? this.creatures : items;
    final found = [
      for (final e in names.entries)
        if (_norm(e.value).contains(q)) e,
    ];
    int rank(MapEntry<String, String> e) =>
        _norm(e.value).startsWith(q) ? 0 : 1;
    found.sort(
      (a, b) => rank(a) != rank(b)
          ? rank(a) - rank(b)
          : a.value.length != b.value.length
          ? a.value.length - b.value.length
          : a.key.compareTo(b.key),
    );
    return [for (final e in found.take(limit)) e.key];
  }
}

String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');
