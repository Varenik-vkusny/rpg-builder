// Библиотека образцов Open5e (api.open5e.com/v2): SRD 5.1 / 5.2 под CC BY 4.0 (VISION.md, §10).
// Только чтение и только предметы: обычные (/items) и магические (/magicitems).
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Образец предмета из Open5e — ровно то, что нужно для импорта и атрибуции.
class Open5eItem {
  const Open5eItem({
    required this.key,
    required this.name,
    required this.category,
    this.rarity,
    this.cost,
    this.damageDice,
    this.armorClass,
    required this.document,
  });

  /// Постоянный ключ образца (`srd-2024_war-pick`) — он и есть source_ref.
  final String key;
  final String name;

  /// Ключ категории: weapon, armor, potion, scroll, adventuring-gear…
  final String category;

  /// Ключ редкости Open5e: common … very-rare, legendary, artifact; у обычных предметов нет.
  final String? rarity;

  /// Цена в золотых.
  final double? cost;
  final String? damageDice;
  final int? armorClass;

  /// Документ-источник для атрибуции: «System Reference Document 5.2».
  final String document;

  factory Open5eItem.fromJson(Map<String, dynamic> j) => Open5eItem(
    key: j['key'] as String,
    name: j['name'] as String,
    category: ((j['category'] as Map?)?['key'] as String?) ?? 'misc',
    rarity: (j['rarity'] as Map?)?['key'] as String?,
    cost: double.tryParse('${j['cost']}'),
    damageDice: (j['weapon'] as Map?)?['damage_dice'] as String?,
    armorClass: (j['armor'] as Map?)?['ac_base'] as int?,
    document: ((j['document'] as Map?)?['name'] as String?) ?? 'Open5e',
  );
}

/// Поиск образцов. Подменяется в тестах — сеть там не нужна.
abstract class Open5eApi {
  Future<List<Open5eItem>> searchItems(String query);
}

class HttpOpen5e implements Open5eApi {
  const HttpOpen5e();

  static const _base = 'https://api.open5e.com/v2';

  @override
  Future<List<Open5eItem>> searchItems(String query) async {
    final lists = await Future.wait([
      for (final kind in ['items', 'magicitems']) _search(kind, query),
    ]);
    return [for (final l in lists) ...l];
  }

  Future<List<Open5eItem>> _search(String kind, String query) async {
    final url = Uri.parse('$_base/$kind/')
        .replace(queryParameters: {'name__icontains': query, 'limit': '20'});
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Open5eError('Open5e ответил ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final r in body['results'] as List)
        Open5eItem.fromJson(r as Map<String, dynamic>),
    ];
  }
}

class Open5eError implements Exception {
  const Open5eError(this.message);
  final String message;
  @override
  String toString() => message;
}
