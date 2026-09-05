// 檔案名稱：lib/core/models/point_setting_model.dart
// 功能說明：記錄點數功能、發點模式、換點比例、有效期限與發放規則
// 🪙 店家點數制度設定模型

import 'package:cloud_firestore/cloud_firestore.dart';

class PointSettingModel {
  const PointSettingModel({
    required this.shopId,
    required this.enabled,
    this.everEnabled = false,
    required this.amountPerPoint,
    required this.pointExpireDays,
    required this.issueAfterCompleted,
    required this.createdAt,
    required this.updatedAt,
    this.calculationType = calculationTypeAmount,
    this.pointsPerNight = 1,
    this.minimumOrderAmount = 0,
    this.maximumPointsPerBooking = 0,
    this.allowManualAdjustment = true,
    this.allowPointsExchange = true,
    this.pointName = '點',
    this.description = '',
    this.createdBy = '',
    this.updatedBy = '',
    this.daycareEarnEnabled = false,
    this.daycareSpendEnabled = false,
    this.daycareCalculationType = daycareCalculationTypeAmount,
    this.daycareAmountPerPoint = 100,
    this.daycarePointsPerOrder = 0,
    this.daycareMinimumOrderAmount = 0,
    this.daycareMaximumPointsPerBooking = 0,
    this.daycareIncludeAddons = true,
    this.daycareIncludeSurcharge = true,
    this.daycareIncludeOvertime = true,
  });

  /// 依消費金額計算點數
  static const String calculationTypeAmount = 'amount';

  /// 依住宿晚數計算點數
  static const String calculationTypeNight = 'night';

  /// 臨托：依消費金額
  static const String daycareCalculationTypeAmount = 'amount';

  /// 臨托：每張完成訂單固定點數
  static const String daycareCalculationTypeFixed = 'fixed';

  /// 所屬店家 ID
  final String shopId;

  /// 是否啟用點數功能
  final bool enabled;

  /// 店家是否曾經啟用過點數制度
  ///
  /// 一旦曾經啟用就永久維持 true，
  /// 日後關閉點數制度時也不會改回 false。
  final bool everEnabled;

  /// 點數計算方式
  ///
  /// amount：依消費金額
  /// night：依住宿晚數
  final String calculationType;

  /// 消費多少元獲得 1 點
  ///
  /// 只有 calculationType == amount 時使用。
  final int amountPerPoint;

  /// 每住宿 1 晚獲得多少點
  ///
  /// 只有 calculationType == night 時使用。
  final int pointsPerNight;

  /// 訂單最低消費金額
  ///
  /// 低於此金額不發點。
  /// 0 代表不限制。
  final int minimumOrderAmount;

  /// 每筆訂單最多可獲得點數
  ///
  /// 0 代表不限制。
  final int maximumPointsPerBooking;

  /// 點數有效天數
  ///
  /// 0 代表永久有效。
  final int pointExpireDays;

  /// 是否必須等訂單完成後才發放點數
  final bool issueAfterCompleted;

  /// 店家是否允許後台手動增減會員點數
  final bool allowManualAdjustment;

  /// 是否開放會員使用點數兌換商品
  final bool allowPointsExchange;

  /// 點數顯示名稱
  final String pointName;

  /// 點數制度說明
  final String description;

  /// 臨托完成後是否發放點數
  final bool daycareEarnEnabled;

  /// 臨托是否允許點數折抵
  final bool daycareSpendEnabled;

  /// 臨托點數計算方式：amount / fixed
  final String daycareCalculationType;

  /// 臨托依消費金額：每消費多少元獲得多少點（與 stay amountPerPoint 相同語意為「每 N 元 1 點」）
  final int daycareAmountPerPoint;

  /// 臨托固定點數：每張完成訂單獲得多少點
  final int daycarePointsPerOrder;

  final int daycareMinimumOrderAmount;
  final int daycareMaximumPointsPerBooking;
  final bool daycareIncludeAddons;
  final bool daycareIncludeSurcharge;
  final bool daycareIncludeOvertime;

  /// 建立人 UID
  final String createdBy;

  /// 最後修改人 UID
  final String updatedBy;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 是否使用依消費金額發點
  bool get isAmountCalculation => calculationType == calculationTypeAmount;

  /// 是否使用依住宿晚數發點
  bool get isNightCalculation => calculationType == calculationTypeNight;

  /// 是否有點數期限
  bool get hasExpiry => pointExpireDays > 0;

  /// 是否有訂單最低消費限制
  bool get hasMinimumOrderAmount => minimumOrderAmount > 0;

  /// 是否有單筆點數上限
  bool get hasMaximumPointsPerBooking => maximumPointsPerBooking > 0;

  /// 根據訂單金額與住宿晚數計算應發點數
  int calculatePoints({required int orderAmount, required int nights}) {
    if (!enabled) {
      return 0;
    }

    if (minimumOrderAmount > 0 && orderAmount < minimumOrderAmount) {
      return 0;
    }

    int points = 0;

    if (isNightCalculation) {
      if (nights <= 0 || pointsPerNight <= 0) {
        return 0;
      }

      points = nights * pointsPerNight;
    } else {
      if (orderAmount <= 0 || amountPerPoint <= 0) {
        return 0;
      }

      points = orderAmount ~/ amountPerPoint;
    }

    if (maximumPointsPerBooking > 0 && points > maximumPointsPerBooking) {
      points = maximumPointsPerBooking;
    }

    return points;
  }

  /// 臨托完成訂單應發點數
  int calculateDaycarePoints({
    required int orderAmount,
    required bool isAppMember,
  }) {
    if (!enabled || !daycareEarnEnabled || !isAppMember) {
      return 0;
    }
    if (daycareMinimumOrderAmount > 0 &&
        orderAmount < daycareMinimumOrderAmount) {
      return 0;
    }
    int points = 0;
    if (daycareCalculationType == daycareCalculationTypeFixed) {
      points = daycarePointsPerOrder > 0 ? daycarePointsPerOrder : 0;
    } else {
      if (orderAmount <= 0 || daycareAmountPerPoint <= 0) {
        return 0;
      }
      points = orderAmount ~/ daycareAmountPerPoint;
    }
    if (daycareMaximumPointsPerBooking > 0 &&
        points > daycareMaximumPointsPerBooking) {
      points = daycareMaximumPointsPerBooking;
    }
    return points;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'enabled': enabled,
      'everEnabled': everEnabled || enabled,
      'calculationType': calculationType,
      'amountPerPoint': amountPerPoint,
      'pointsPerNight': pointsPerNight,
      'minimumOrderAmount': minimumOrderAmount,
      'maximumPointsPerBooking': maximumPointsPerBooking,
      'pointExpireDays': pointExpireDays,
      'issueAfterCompleted': issueAfterCompleted,
      'allowManualAdjustment': allowManualAdjustment,
      'allowPointsExchange': allowPointsExchange,
      'pointName': pointName.trim().isEmpty ? '點' : pointName.trim(),
      'description': description.trim(),
      'daycareEarnEnabled': daycareEarnEnabled,
      'daycareSpendEnabled': daycareSpendEnabled,
      'daycareCalculationType':
          daycareCalculationType == daycareCalculationTypeFixed
          ? daycareCalculationTypeFixed
          : daycareCalculationTypeAmount,
      'daycareAmountPerPoint': daycareAmountPerPoint,
      'daycarePointsPerOrder': daycarePointsPerOrder,
      'daycareMinimumOrderAmount': daycareMinimumOrderAmount,
      'daycareMaximumPointsPerBooking': daycareMaximumPointsPerBooking,
      'daycareIncludeAddons': daycareIncludeAddons,
      'daycareIncludeSurcharge': daycareIncludeSurcharge,
      'daycareIncludeOvertime': daycareIncludeOvertime,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PointSettingModel.fromMap({
    required String shopId,
    required Map<String, dynamic> data,
  }) {
    final String rawCalculationType =
        (data['calculationType'] ?? calculationTypeAmount).toString();

    final String normalizedCalculationType =
        rawCalculationType == calculationTypeNight
        ? calculationTypeNight
        : calculationTypeAmount;

    return PointSettingModel(
      shopId: shopId,
      enabled: data['enabled'] == true,
      calculationType: normalizedCalculationType,
      amountPerPoint: _intFromValue(data['amountPerPoint'], defaultValue: 100),
      pointsPerNight: _intFromValue(data['pointsPerNight'], defaultValue: 1),
      minimumOrderAmount: _intFromValue(data['minimumOrderAmount']),
      maximumPointsPerBooking: _intFromValue(data['maximumPointsPerBooking']),
      pointExpireDays: _intFromValue(
        data['pointExpireDays'],
        defaultValue: 365,
      ),
      issueAfterCompleted: data['issueAfterCompleted'] != false,
      allowManualAdjustment: data['allowManualAdjustment'] != false,
      allowPointsExchange: data['allowPointsExchange'] != false,
      pointName: (data['pointName'] ?? '點').toString(),
      description: (data['description'] ?? '').toString(),
      daycareEarnEnabled: data['daycareEarnEnabled'] == true,
      daycareSpendEnabled: data['daycareSpendEnabled'] == true,
      daycareCalculationType:
          (data['daycareCalculationType'] ?? daycareCalculationTypeAmount)
                  .toString() ==
              daycareCalculationTypeFixed
          ? daycareCalculationTypeFixed
          : daycareCalculationTypeAmount,
      daycareAmountPerPoint: _intFromValue(
        data['daycareAmountPerPoint'],
        defaultValue: _intFromValue(data['amountPerPoint'], defaultValue: 100),
      ),
      daycarePointsPerOrder: _intFromValue(data['daycarePointsPerOrder']),
      daycareMinimumOrderAmount: _intFromValue(
        data['daycareMinimumOrderAmount'],
      ),
      daycareMaximumPointsPerBooking: _intFromValue(
        data['daycareMaximumPointsPerBooking'],
      ),
      daycareIncludeAddons: data['daycareIncludeAddons'] != false,
      daycareIncludeSurcharge: data['daycareIncludeSurcharge'] != false,
      daycareIncludeOvertime: data['daycareIncludeOvertime'] != false,
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(data['updatedAt']) ?? DateTime.now(),
    );
  }

  PointSettingModel copyWith({
    String? shopId,
    bool? enabled,
    bool? everEnabled,
    String? calculationType,
    int? amountPerPoint,
    int? pointsPerNight,
    int? minimumOrderAmount,
    int? maximumPointsPerBooking,
    int? pointExpireDays,
    bool? issueAfterCompleted,
    bool? allowManualAdjustment,
    bool? allowPointsExchange,
    String? pointName,
    String? description,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? daycareEarnEnabled,
    bool? daycareSpendEnabled,
    String? daycareCalculationType,
    int? daycareAmountPerPoint,
    int? daycarePointsPerOrder,
    int? daycareMinimumOrderAmount,
    int? daycareMaximumPointsPerBooking,
    bool? daycareIncludeAddons,
    bool? daycareIncludeSurcharge,
    bool? daycareIncludeOvertime,
  }) {
    return PointSettingModel(
      shopId: shopId ?? this.shopId,
      enabled: enabled ?? this.enabled,
      everEnabled: everEnabled ?? this.everEnabled,
      calculationType: calculationType ?? this.calculationType,
      amountPerPoint: amountPerPoint ?? this.amountPerPoint,
      pointsPerNight: pointsPerNight ?? this.pointsPerNight,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      maximumPointsPerBooking:
          maximumPointsPerBooking ?? this.maximumPointsPerBooking,
      pointExpireDays: pointExpireDays ?? this.pointExpireDays,
      issueAfterCompleted: issueAfterCompleted ?? this.issueAfterCompleted,
      allowManualAdjustment:
          allowManualAdjustment ?? this.allowManualAdjustment,
      allowPointsExchange: allowPointsExchange ?? this.allowPointsExchange,
      pointName: pointName ?? this.pointName,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      daycareEarnEnabled: daycareEarnEnabled ?? this.daycareEarnEnabled,
      daycareSpendEnabled: daycareSpendEnabled ?? this.daycareSpendEnabled,
      daycareCalculationType:
          daycareCalculationType ?? this.daycareCalculationType,
      daycareAmountPerPoint:
          daycareAmountPerPoint ?? this.daycareAmountPerPoint,
      daycarePointsPerOrder:
          daycarePointsPerOrder ?? this.daycarePointsPerOrder,
      daycareMinimumOrderAmount:
          daycareMinimumOrderAmount ?? this.daycareMinimumOrderAmount,
      daycareMaximumPointsPerBooking:
          daycareMaximumPointsPerBooking ?? this.daycareMaximumPointsPerBooking,
      daycareIncludeAddons: daycareIncludeAddons ?? this.daycareIncludeAddons,
      daycareIncludeSurcharge:
          daycareIncludeSurcharge ?? this.daycareIncludeSurcharge,
      daycareIncludeOvertime:
          daycareIncludeOvertime ?? this.daycareIncludeOvertime,
    );
  }
}

DateTime? _dateTimeFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}

int _intFromValue(dynamic value, {int defaultValue = 0}) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? defaultValue;
}
