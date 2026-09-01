// lib/core/services/daycare_addon_catalog.dart
// 🐾 臨托可用加購：只讀既有加購服務，允許清單以臨托設定 allowedAddonIds 為準。

class DaycareAddonCatalog {
  DaycareAddonCatalog._();

  static const List<Map<String, String>> groups = <Map<String, String>>[
    <String, String>{'key': 'timeOptions', 'label': '時間加購'},
    <String, String>{'key': 'valueServices', 'label': '加值服務'},
    <String, String>{'key': 'customServices', 'label': '客製服務'},
    <String, String>{'key': 'dailyTimedServices', 'label': '每日分時段'},
  ];

  static String displayName(Map<String, dynamic> item) {
    final String name = (item['name'] ?? item['label'] ?? '').toString().trim();
    return name;
  }

  static String chargeLabel(Map<String, dynamic> item) {
    switch ((item['daycareChargeMode'] ?? 'per_order').toString()) {
      case 'per_pet':
        return '每隻計費';
      case 'per_hour':
        return '每小時計費';
      case 'per_slot':
        return '每時段計費';
      case 'custom':
        return '自訂數量';
      default:
        return '每次計費';
    }
  }

  static String inventorySummary(Map<String, dynamic> item) {
    if (item['useInventory'] != true) {
      return '不使用庫存';
    }
    final Object? raw = item['inventoryBindings'];
    final int count = raw is List ? raw.length : 0;
    return count > 0 ? '庫存連動 · 已綁定 $count 項' : '庫存連動 · 尚未綁定';
  }

  static List<Map<String, dynamic>> flatten(Map<String, dynamic>? doc) {
    if (doc == null || doc['enabled'] == false) {
      return const <Map<String, dynamic>>[];
    }
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    for (final Map<String, String> group in groups) {
      final Object? raw = doc[group['key']];
      final List<dynamic> list = raw is List ? raw : const <dynamic>[];
      for (final dynamic item in list) {
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> map = Map<String, dynamic>.from(item);
        final String id = (map['id'] ?? '').toString().trim();
        if (id.isEmpty) {
          continue;
        }
        map['groupKey'] = group['key'];
        map['groupLabel'] = group['label'];
        out.add(map);
      }
    }
    return out;
  }

  static List<Map<String, dynamic>> allowedForDaycare({
    required Map<String, dynamic>? doc,
    required List<String> allowedAddonIds,
  }) {
    final Set<String> allowed = allowedAddonIds.toSet();
    return flatten(doc)
        .where(
          (Map<String, dynamic> item) =>
              allowed.contains((item['id'] ?? '').toString()),
        )
        .toList();
  }

  static bool isAllowed({
    required List<String> allowedAddonIds,
    required String addonId,
  }) {
    final String id = addonId.trim();
    return id.isNotEmpty && allowedAddonIds.contains(id);
  }
}
