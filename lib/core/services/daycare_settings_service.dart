// lib/core/services/daycare_settings_service.dart
// 🐾 臨托設定：shops/{shopId}/daycare_settings/main

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';

class DaycareSettingsService {
  DaycareSettingsService._();

  static final DaycareSettingsService instance = DaycareSettingsService._();

  static const String collection = 'daycare_settings';
  static const String docId = 'main';

  DocumentReference<Map<String, dynamic>> _ref(String shopId) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection(collection)
        .doc(docId);
  }

  Future<DaycareSettingsModel> get(String shopId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _ref(
      shopId,
    ).get();
    return DaycareSettingsModel.fromMap(snap.data());
  }

  Stream<DaycareSettingsModel> stream(String shopId) {
    return _ref(shopId).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) =>
          DaycareSettingsModel.fromMap(snap.data()),
    );
  }

  Future<void> save({
    required String shopId,
    required DaycareSettingsModel settings,
  }) {
    return _ref(shopId).set(settings.toMap(), SetOptions(merge: true));
  }

  /// 臨托唯一啟用來源：`shops/{shopId}.daycareEnabled`。
  /// 舊資料若尚未寫入該欄，才安全讀取臨托設定的 `enabled`。
  bool isEnabledForShop({
    required Map<String, dynamic>? shop,
    DaycareSettingsModel? settings,
  }) {
    if (shop != null && shop.containsKey('daycareEnabled')) {
      return shop['daycareEnabled'] == true;
    }
    return settings?.enabled == true;
  }

  bool isCatHotelEnabled(Map<String, dynamic>? shop) {
    final List<dynamic> modules = shop?['enabledModules'] is List
        ? shop!['enabledModules'] as List<dynamic>
        : const <dynamic>[];
    return modules
        .map((dynamic item) => item.toString())
        .contains(ShopModules.catHotel);
  }
}
