// 檔案名稱：lib/core/services/daily_care_setting_service.dart
// 功能說明：讀取、監聽與儲存店家的每日照護紀錄設定。
// 🐾 每日照護紀錄設定 Service

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_care_setting_model.dart';

class DailyCareSettingService {
  DailyCareSettingService._();

  static final DailyCareSettingService instance = DailyCareSettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _shopReference(String shopId) {
    return _firestore.collection('shops').doc(shopId);
  }

  /// 即時監聽每日照護紀錄設定
  Stream<DailyCareSettingModel> streamSetting(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<DailyCareSettingModel>.value(const DailyCareSettingModel());
    }

    return _shopReference(normalizedShopId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (data == null) {
        return const DailyCareSettingModel();
      }

      final Object? rawSetting = data['dailyCareSetting'];

      if (rawSetting is! Map) {
        return const DailyCareSettingModel();
      }

      return DailyCareSettingModel.fromMap(
        Map<String, dynamic>.from(rawSetting),
      );
    });
  }

  /// 單次取得每日照護紀錄設定
  Future<DailyCareSettingModel> getSetting(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _shopReference(normalizedShopId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (data == null) {
      return const DailyCareSettingModel();
    }

    final Object? rawSetting = data['dailyCareSetting'];

    if (rawSetting is! Map) {
      return const DailyCareSettingModel();
    }

    return DailyCareSettingModel.fromMap(Map<String, dynamic>.from(rawSetting));
  }

  /// 儲存每日照護紀錄設定
  Future<void> saveSetting({
    required String shopId,
    required DailyCareSettingModel setting,
  }) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    await _shopReference(normalizedShopId).set(<String, dynamic>{
      'dailyCareSetting': setting.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
