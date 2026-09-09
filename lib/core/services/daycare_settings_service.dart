// 檔案名稱：lib/core/services/daycare_settings_service.dart
// 功能說明：安親設定：shops/{shopId}/daycare_settings/main
// 總開關正式欄位：shops/{shopId}.daycareEnabled（與 settings.enabled 同步寫入）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_enabled.dart';

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

  DocumentReference<Map<String, dynamic>> _shopRef(String shopId) {
    return FirebaseFirestore.instance.collection('shops').doc(shopId);
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
  }) async {
    await _ref(shopId).set(settings.toMap(), SetOptions(merge: true));
    await _shopRef(shopId).set(<String, dynamic>{
      'daycareEnabled': settings.enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 預約設定頁切換總開關時，同步寫入設定文件，避免兩邊讀到不同結果。
  Future<void> syncEnabledFlag({
    required String shopId,
    required bool enabled,
  }) async {
    await _ref(shopId).set(<String, dynamic>{
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _shopRef(shopId).set(<String, dynamic>{
      'daycareEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 正式來源：shops.daycareEnabled。關閉後即使 settings.enabled 仍為 true 也視為關閉。
  bool isEnabledForShop({
    required Map<String, dynamic>? shop,
    DaycareSettingsModel? settings,
  }) {
    return DaycareEnabled.isOn(shop: shop, settings: settings);
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
