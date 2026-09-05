// 檔案名稱：lib/core/services/point_setting_service.dart
// 功能說明：讀取、監聽與儲存每間店家的點數制度設定
// 🪙 店家點數設定 Service
// 並支援依消費金額或住宿晚數計算點數

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/point_setting_model.dart';

class PointSettingService {
  PointSettingService._();

  static final PointSettingService instance = PointSettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> _settingReference(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('settings')
        .doc('points');
  }

  /// 即時監聽店家的點數設定
  ///
  /// 尚未建立設定時，回傳預設設定，
  /// 但不會自動寫入 Firestore。
  Stream<PointSettingModel> streamPointSetting(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<PointSettingModel>.value(_defaultSetting(''));
    }

    return _settingReference(normalizedShopId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return _defaultSetting(normalizedShopId);
      }

      return PointSettingModel.fromMap(shopId: normalizedShopId, data: data);
    });
  }

  /// 一次取得店家的點數設定
  ///
  /// 尚未建立時回傳預設設定。
  Future<PointSettingModel> getPointSetting(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return _defaultSetting('');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _settingReference(normalizedShopId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return _defaultSetting(normalizedShopId);
    }

    return PointSettingModel.fromMap(shopId: normalizedShopId, data: data);
  }

  /// 確保店家已建立點數設定
  ///
  /// 如果尚未建立，寫入一份預設設定。
  /// 已存在時不覆蓋原本資料。
  Future<PointSettingModel> ensurePointSetting(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    final DocumentReference<Map<String, dynamic>> reference = _settingReference(
      normalizedShopId,
    );

    return _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);

      final Map<String, dynamic>? data = snapshot.data();

      if (snapshot.exists && data != null) {
        return PointSettingModel.fromMap(shopId: normalizedShopId, data: data);
      }

      final DateTime now = DateTime.now();
      final String currentUid = _auth.currentUser?.uid ?? '';

      final PointSettingModel setting = PointSettingModel(
        shopId: normalizedShopId,
        enabled: false,
        everEnabled: false,
        calculationType: PointSettingModel.calculationTypeAmount,
        amountPerPoint: 100,
        pointsPerNight: 1,
        minimumOrderAmount: 0,
        maximumPointsPerBooking: 0,
        pointExpireDays: 365,
        issueAfterCompleted: true,
        allowManualAdjustment: true,
        allowPointsExchange: true,
        pointName: '點',
        description: '',
        createdBy: currentUid,
        updatedBy: currentUid,
        createdAt: now,
        updatedAt: now,
      );

      transaction.set(reference, setting.toMap());

      return setting;
    });
  }

  /// 儲存店家的點數設定
  Future<void> savePointSetting({
    required String shopId,
    required bool enabled,
    required String calculationType,
    required int amountPerPoint,
    required int pointsPerNight,
    required int minimumOrderAmount,
    required int maximumPointsPerBooking,
    required int pointExpireDays,
    required bool issueAfterCompleted,
    required bool allowManualAdjustment,
    required bool allowPointsExchange,
    required String pointName,
    required String description,
    bool daycareEarnEnabled = false,
    bool daycareSpendEnabled = false,
    String daycareCalculationType =
        PointSettingModel.daycareCalculationTypeAmount,
    int daycareAmountPerPoint = 100,
    int daycarePointsPerOrder = 0,
    int daycareMinimumOrderAmount = 0,
    int daycareMaximumPointsPerBooking = 0,
    bool daycareIncludeAddons = true,
    bool daycareIncludeSurcharge = true,
    bool daycareIncludeOvertime = true,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedPointName = pointName.trim();
    final String normalizedDescription = description.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    _validateSetting(
      calculationType: calculationType,
      amountPerPoint: amountPerPoint,
      pointsPerNight: pointsPerNight,
      minimumOrderAmount: minimumOrderAmount,
      maximumPointsPerBooking: maximumPointsPerBooking,
      pointExpireDays: pointExpireDays,
      pointName: normalizedPointName,
    );

    final DocumentReference<Map<String, dynamic>> reference = _settingReference(
      normalizedShopId,
    );

    final String currentUid = _auth.currentUser?.uid ?? '';

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);

      final Map<String, dynamic>? currentData = snapshot.data();

      if (!snapshot.exists || currentData == null) {
        final DateTime now = DateTime.now();

        final PointSettingModel newSetting = PointSettingModel(
          shopId: normalizedShopId,
          enabled: enabled,
          everEnabled: enabled,
          calculationType: calculationType,
          amountPerPoint: amountPerPoint,
          pointsPerNight: pointsPerNight,
          minimumOrderAmount: minimumOrderAmount,
          maximumPointsPerBooking: maximumPointsPerBooking,
          pointExpireDays: pointExpireDays,
          issueAfterCompleted: issueAfterCompleted,
          allowManualAdjustment: allowManualAdjustment,
          allowPointsExchange: allowPointsExchange,
          pointName: normalizedPointName,
          description: normalizedDescription,
          createdBy: currentUid,
          updatedBy: currentUid,
          createdAt: now,
          updatedAt: now,
          daycareEarnEnabled: daycareEarnEnabled,
          daycareSpendEnabled: daycareSpendEnabled,
          daycareCalculationType: daycareCalculationType,
          daycareAmountPerPoint: daycareAmountPerPoint,
          daycarePointsPerOrder: daycarePointsPerOrder,
          daycareMinimumOrderAmount: daycareMinimumOrderAmount,
          daycareMaximumPointsPerBooking: daycareMaximumPointsPerBooking,
          daycareIncludeAddons: daycareIncludeAddons,
          daycareIncludeSurcharge: daycareIncludeSurcharge,
          daycareIncludeOvertime: daycareIncludeOvertime,
        );

        transaction.set(reference, newSetting.toMap());
        return;
      }

      final bool currentEverEnabled =
          currentData['everEnabled'] == true || currentData['enabled'] == true;

      transaction.update(reference, <String, dynamic>{
        'enabled': enabled,
        'everEnabled': currentEverEnabled || enabled,
        'calculationType': calculationType,
        'amountPerPoint': amountPerPoint,
        'pointsPerNight': pointsPerNight,
        'minimumOrderAmount': minimumOrderAmount,
        'maximumPointsPerBooking': maximumPointsPerBooking,
        'pointExpireDays': pointExpireDays,
        'issueAfterCompleted': issueAfterCompleted,
        'allowManualAdjustment': allowManualAdjustment,
        'allowPointsExchange': allowPointsExchange,
        'pointName': normalizedPointName,
        'description': normalizedDescription,
        'daycareEarnEnabled': daycareEarnEnabled,
        'daycareSpendEnabled': daycareSpendEnabled,
        'daycareCalculationType': daycareCalculationType,
        'daycareAmountPerPoint': daycareAmountPerPoint,
        'daycarePointsPerOrder': daycarePointsPerOrder,
        'daycareMinimumOrderAmount': daycareMinimumOrderAmount,
        'daycareMaximumPointsPerBooking': daycareMaximumPointsPerBooking,
        'daycareIncludeAddons': daycareIncludeAddons,
        'daycareIncludeSurcharge': daycareIncludeSurcharge,
        'daycareIncludeOvertime': daycareIncludeOvertime,
        'updatedBy': currentUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 根據店家目前設定，計算訂單可獲得點數
  Future<int> calculateBookingPoints({
    required String shopId,
    required int orderAmount,
    required int nights,
  }) async {
    final PointSettingModel setting = await getPointSetting(shopId);

    return setting.calculatePoints(orderAmount: orderAmount, nights: nights);
  }

  /// 預設點數設定
  PointSettingModel _defaultSetting(String shopId) {
    final DateTime now = DateTime.now();

    return PointSettingModel(
      shopId: shopId,
      enabled: false,
      calculationType: PointSettingModel.calculationTypeAmount,
      amountPerPoint: 100,
      pointsPerNight: 1,
      minimumOrderAmount: 0,
      maximumPointsPerBooking: 0,
      pointExpireDays: 365,
      issueAfterCompleted: true,
      allowManualAdjustment: true,
      allowPointsExchange: true,
      pointName: '點',
      description: '',
      createdBy: '',
      updatedBy: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  void _validateSetting({
    required String calculationType,
    required int amountPerPoint,
    required int pointsPerNight,
    required int minimumOrderAmount,
    required int maximumPointsPerBooking,
    required int pointExpireDays,
    required String pointName,
  }) {
    final bool isAmountCalculation =
        calculationType == PointSettingModel.calculationTypeAmount;

    final bool isNightCalculation =
        calculationType == PointSettingModel.calculationTypeNight;

    if (!isAmountCalculation && !isNightCalculation) {
      throw ArgumentError('點數計算方式不正確');
    }

    if (isAmountCalculation && amountPerPoint <= 0) {
      throw ArgumentError('每點消費金額必須大於 0');
    }

    if (isNightCalculation && pointsPerNight <= 0) {
      throw ArgumentError('每晚發放點數必須大於 0');
    }

    if (minimumOrderAmount < 0) {
      throw ArgumentError('最低消費金額不能小於 0');
    }

    if (maximumPointsPerBooking < 0) {
      throw ArgumentError('單筆最多點數不能小於 0');
    }

    if (pointExpireDays < 0) {
      throw ArgumentError('點數有效天數不能小於 0');
    }

    if (pointName.isEmpty) {
      throw ArgumentError('請輸入點數名稱');
    }

    if (pointName.length > 10) {
      throw ArgumentError('點數名稱最多 10 個字');
    }
  }
}
