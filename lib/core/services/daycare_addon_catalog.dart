// lib/core/services/daycare_addon_catalog.dart
// 🐾 安親可用加購：只讀既有 shops/{shopId}/addons/main，允許清單為 allowedAddonIds。

import 'package:petnest_saas/core/models/daycare_settings_model.dart';

class DaycareAddonCatalog {
  DaycareAddonCatalog._();

  static const List<Map<String, String>> groups = <Map<String, String>>[
    <String, String>{'key': 'timeOptions', 'label': '時間加購'},
    <String, String>{'key': 'valueServices', 'label': '加值服務'},
    <String, String>{'key': 'customServices', 'label': '客製服務'},
    <String, String>{'key': 'dailyTimedServices', 'label': '每日分時段服務'},
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
    if (!DaycareBool.parse(item['useInventory'])) {
      return '不使用庫存';
    }
    final Object? raw = item['inventoryBindings'];
    final int count = raw is List ? raw.length : 0;
    return count > 0 ? '庫存連動 · 已綁定 $count 項' : '庫存連動 · 尚未綁定';
  }

  static bool isModuleEnabled(Map<String, dynamic>? doc) {
    if (doc == null) {
      return false;
    }
    if (!doc.containsKey('enabled')) {
      return true;
    }
    return DaycareBool.parse(doc['enabled']);
  }

  static bool isItemEnabled(Map<String, dynamic> item) {
    if (!item.containsKey('enabled')) {
      return true;
    }
    return DaycareBool.parse(item['enabled']);
  }

  /// 後台清單：即使加購總開關關閉仍列出項目，方便勾選。
  static List<Map<String, dynamic>> flatten(Map<String, dynamic>? doc) {
    if (doc == null) {
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
    DateTime? serviceDate,
    int petCount = 1,
  }) {
    if (!isModuleEnabled(doc)) {
      return const <Map<String, dynamic>>[];
    }
    final Set<String> allowed = allowedAddonIds.toSet();
    return flatten(doc).where((Map<String, dynamic> item) {
      final String id = (item['id'] ?? '').toString();
      if (!allowed.contains(id) || !isItemEnabled(item)) {
        return false;
      }
      return _matchesDateAndPets(
        item: item,
        serviceDate: serviceDate,
        petCount: petCount,
      );
    }).toList();
  }

  static bool _matchesDateAndPets({
    required Map<String, dynamic> item,
    DateTime? serviceDate,
    required int petCount,
  }) {
    final int minPets = _toInt(item['minPets'], 0);
    final int maxPets = _toInt(item['maxPets'], 0);
    if (minPets > 0 && petCount < minPets) {
      return false;
    }
    if (maxPets > 0 && petCount > maxPets) {
      return false;
    }
    if (serviceDate == null) {
      return true;
    }
    final Object? weekdaysRaw = item['weekdays'] ?? item['allowedWeekdays'];
    if (weekdaysRaw is List && weekdaysRaw.isNotEmpty) {
      final Set<int> days = weekdaysRaw
          .map((dynamic e) => int.tryParse(e.toString()) ?? 0)
          .where((int e) => e >= 1 && e <= 7)
          .toSet();
      if (days.isNotEmpty && !days.contains(serviceDate.weekday)) {
        return false;
      }
    }
    return true;
  }

  static bool isAllowed({
    required List<String> allowedAddonIds,
    required String addonId,
  }) {
    final String id = addonId.trim();
    return id.isNotEmpty && allowedAddonIds.contains(id);
  }

  static int _toInt(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}
