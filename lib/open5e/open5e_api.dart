// Библиотека образцов Open5e (api.open5e.com/v2): SRD 5.1 / 5.2 под CC BY 4.0 (VISION.md, §10).
// Только чтение: предметы — обычные (/items) и магические (/magicitems), существа (/creatures).
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

/// Образец существа из Open5e (5д): что нужно для наших трёх чисел и значка, плюс ответ
/// целиком — он хранится при враге как карточка оригинала.
class Open5eCreature {
  const Open5eCreature({
    required this.key,
    required this.name,
    required this.type,
    required this.challenge,
    required this.hp,
    required this.document,
    this.firstAttack,
    this.raw = const {},
  });

  final String key;
  final String name;

  /// Ключ типа существа: undead, ooze, beast, humanoid…
  final String type;

  /// Опасность (CR): 0.25, 2, 10…
  final double challenge;
  final int hp;
  final String document;

  /// Кости первой атаки по порядку в статблоке: (2, 6, 0) — 2d6+0. Атак нет — null.
  final (int, int, int)? firstAttack;
  final Map<String, dynamic> raw;

  factory Open5eCreature.fromJson(Map<String, dynamic> j) {
    final actions = [...(j['actions'] as List? ?? const [])]
      ..sort(
        (a, b) => ((a as Map)['order_in_statblock'] as int? ?? 0).compareTo(
          (b as Map)['order_in_statblock'] as int? ?? 0,
        ),
      );
    (int, int, int)? first;
    for (final a in actions) {
      for (final at in (a as Map)['attacks'] as List? ?? const []) {
        final m = at as Map;
        final n = m['damage_die_count'] as int?;
        // «D6» → 6.
        final d = int.tryParse(
          '${m['damage_die_type'] ?? ''}'.replaceAll(RegExp(r'\D'), ''),
        );
        if (n != null && d != null) {
          first ??= (n, d, m['damage_bonus'] as int? ?? 0);
        }
      }
    }
    return Open5eCreature(
      key: j['key'] as String,
      name: j['name'] as String,
      type: ((j['type'] as Map?)?['key'] as String?) ?? '',
      challenge: (j['challenge_rating'] as num?)?.toDouble() ?? 0,
      hp: j['hit_points'] as int? ?? 1,
      document: ((j['document'] as Map?)?['name'] as String?) ?? 'Open5e',
      firstAttack: first,
      raw: j,
    );
  }
}

/// Поиск образцов. Подменяется в тестах — сеть там не нужна.
abstract class Open5eApi {
  Future<List<Open5eItem>> searchItems(String query);
  Future<List<Open5eCreature>> searchCreatures(String query);
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

  @override
  Future<List<Open5eCreature>> searchCreatures(String query) async => [
    for (final r in await _get('creatures', query)) Open5eCreature.fromJson(r),
  ];

  Future<List<Open5eItem>> _search(String kind, String query) async => [
    for (final r in await _get(kind, query)) Open5eItem.fromJson(r),
  ];

  Future<List<Map<String, dynamic>>> _get(String kind, String query) async {
    final url = Uri.parse('$_base/$kind/')
        .replace(queryParameters: {'name__icontains': query, 'limit': '20'});
    final res = await http.get(url).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Open5eError('Open5e ответил ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [for (final r in body['results'] as List) r as Map<String, dynamic>];
  }
}

class Open5eError implements Exception {
  const Open5eError(this.message);
  final String message;
  @override
  String toString() => message;
}
