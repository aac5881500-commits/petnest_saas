// test/point_setting_daycare_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';

void main() {
  PointSettingModel setting({
    bool earn = true,
    String type = PointSettingModel.daycareCalculationTypeAmount,
    int amountPerPoint = 100,
    int fixed = 10,
    int min = 0,
    int max = 0,
  }) {
    final DateTime now = DateTime(2026, 9, 1);
    return PointSettingModel(
      shopId: 'shop1',
      enabled: true,
      amountPerPoint: 100,
      pointExpireDays: 365,
      issueAfterCompleted: true,
      createdAt: now,
      updatedAt: now,
      daycareEarnEnabled: earn,
      daycareCalculationType: type,
      daycareAmountPerPoint: amountPerPoint,
      daycarePointsPerOrder: fixed,
      daycareMinimumOrderAmount: min,
      daycareMaximumPointsPerBooking: max,
    );
  }

  test('臨托依消費金額發點且手動會員不發', () {
    expect(
      setting().calculateDaycarePoints(orderAmount: 350, isAppMember: true),
      3,
    );
    expect(
      setting().calculateDaycarePoints(orderAmount: 350, isAppMember: false),
      0,
    );
  });

  test('臨托固定點數與上限', () {
    expect(
      setting(
        type: PointSettingModel.daycareCalculationTypeFixed,
        fixed: 8,
        max: 5,
      ).calculateDaycarePoints(orderAmount: 999, isAppMember: true),
      5,
    );
  });

  test('未達最低消費不發點', () {
    expect(
      setting(
        min: 500,
      ).calculateDaycarePoints(orderAmount: 400, isAppMember: true),
      0,
    );
  });
}
