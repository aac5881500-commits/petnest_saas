// lib/core/services/housekeeping_setting_service.dart
// 🧹 房務設定 Service
// 功能：讀取、監聽與儲存店家的房務設定

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/housekeeping_setting_model.dart';

class HousekeepingSettingService {
  HousekeepingSettingService._();

  static final HousekeepingSettingService instance =
      HousekeepingSettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _shopReference(String shopId) {
    return _firestore.collection('shops').doc(shopId);
  }

  /// 即時監聽房務設定
  ///
  /// 尚未建立設定時，回傳預設設定。
  Stream<HousekeepingSettingModel> streamSetting(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<HousekeepingSettingModel>.value(
        const HousekeepingSettingModel(),
      );
    }

    return _shopReference(normalizedShopId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? shopData = snapshot.data();

      final Object? rawSetting = shopData?['housekeepingSetting'];

      if (rawSetting is! Map) {
        return const HousekeepingSettingModel();
      }

      return HousekeepingSettingModel.fromMap(
        Map<String, dynamic>.from(rawSetting),
      );
    });
  }

  /// 單次取得房務設定
  ///
  /// 尚未建立設定時，回傳預設設定。
  Future<HousekeepingSettingModel> getSetting(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const HousekeepingSettingModel();
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _shopReference(normalizedShopId).get();

    final Map<String, dynamic>? shopData = snapshot.data();

    final Object? rawSetting = shopData?['housekeepingSetting'];

    if (rawSetting is! Map) {
      return const HousekeepingSettingModel();
    }

    return HousekeepingSettingModel.fromMap(
      Map<String, dynamic>.from(rawSetting),
    );
  }

  /// 儲存房務設定
  Future<void> saveSetting({
    required String shopId,
    required bool autoCleaningAfterCheckout,
  }) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    final HousekeepingSettingModel setting = HousekeepingSettingModel(
      autoCleaningAfterCheckout: autoCleaningAfterCheckout,
    );

    await _shopReference(normalizedShopId).set(<String, dynamic>{
      'housekeepingSetting': setting.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
