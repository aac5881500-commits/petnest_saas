// 檔案名稱：test/point_setting_converge_test.dart
// 功能說明：點數制度收斂：安親僅金額發點、舊折抵欄位 migration、手動會員不發點。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';

void main() {
  test('舊 daycareSpendEnabled 對應折抵總開關', () {
    final PointSettingModel setting = PointSettingModel.fromMap(
      shopId: 's1',
      data: <String, dynamic>{'enabled': true, 'daycareSpendEnabled': true},
    );
    expect(setting.spendEnabled, isTrue);
    expect(setting.daycareSpendEnabled, isTrue);
    expect(setting.staySpendEnabled, isFalse);
    expect(setting.pointsPerNtd, 1);
    expect(setting.issueAfterCompleted, isTrue);
  });

  test('安親固定每筆點數不再發點', () {
    final PointSettingModel setting = PointSettingModel(
      shopId: 's1',
      enabled: true,
      amountPerPoint: 100,
      pointExpireDays: 365,
      issueAfterCompleted: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      daycareEarnEnabled: true,
      daycareCalculationType: PointSettingModel.daycareCalculationTypeFixed,
      daycarePointsPerOrder: 9,
      daycareAmountPerPoint: 100,
    );
    expect(
      setting.calculateDaycarePoints(orderAmount: 10, isAppMember: true),
      0,
    );
    expect(
      setting.calculateDaycarePoints(orderAmount: 800, isAppMember: true),
      8,
    );
    expect(
      setting.calculateDaycarePoints(orderAmount: 800, isAppMember: false),
      0,
    );
  });

  test('住宿晚數與金額發點', () {
    final DateTime now = DateTime(2026, 1, 1);
    final PointSettingModel night = PointSettingModel(
      shopId: 's1',
      enabled: true,
      amountPerPoint: 100,
      pointExpireDays: 0,
      issueAfterCompleted: true,
      createdAt: now,
      updatedAt: now,
      calculationType: PointSettingModel.calculationTypeNight,
      pointsPerNight: 5,
    );
    expect(night.calculatePoints(orderAmount: 1, nights: 3), 15);
    final PointSettingModel amount = night.copyWith(
      calculationType: PointSettingModel.calculationTypeAmount,
    );
    expect(amount.calculatePoints(orderAmount: 800, nights: 3), 8);
  });

  test('10 點折 NT\$1：100 點只折 10 元，不可把餘額當台幣', () {
    final DateTime now = DateTime(2026, 1, 1);
    final PointSettingModel setting = PointSettingModel(
      shopId: 's1',
      enabled: true,
      amountPerPoint: 100,
      pointExpireDays: 0,
      issueAfterCompleted: true,
      createdAt: now,
      updatedAt: now,
      spendEnabled: true,
      staySpendEnabled: true,
      daycareSpendEnabled: true,
      pointsPerNtd: 10,
    );
    expect(setting.canSpendOn('stay'), isTrue);
    expect(setting.canSpendOn('daycare'), isTrue);
    final PointSpendCap full = setting.capSpend(
      requestedPoints: 100,
      balance: 100,
      payableAfterCoupon: 500,
    );
    expect(full.pointAmount, 10);
    expect(full.pointsUsed, 100);
    final PointSpendCap partial = setting.capSpend(
      requestedPoints: 40,
      balance: 100,
      payableAfterCoupon: 500,
    );
    expect(partial.pointAmount, 4);
    expect(partial.pointsUsed, 40);
    final PointSpendCap afterCoupon = setting.capSpend(
      requestedPoints: 999999,
      balance: 500,
      payableAfterCoupon: 8,
    );
    expect(afterCoupon.pointAmount, 8);
    expect(afterCoupon.pointsUsed, 80);
    expect(
      PointSettingModel.payableAfterPoints(afterCoupon: 100, pointAmount: 8),
      92,
    );
    expect(
      PointSettingModel.payableAfterPoints(afterCoupon: 10, pointAmount: 80),
      0,
    );
  });

  test('純手動通道關閉時 canSpendOn 仍依設定，前端 walk-in 不送點', () {
    final DateTime now = DateTime(2026, 1, 1);
    final PointSettingModel setting = PointSettingModel(
      shopId: 's1',
      enabled: true,
      amountPerPoint: 100,
      pointExpireDays: 0,
      issueAfterCompleted: true,
      createdAt: now,
      updatedAt: now,
      spendEnabled: true,
      staySpendEnabled: true,
    );
    expect(setting.canSpendOn('stay'), isTrue);
  });
}
