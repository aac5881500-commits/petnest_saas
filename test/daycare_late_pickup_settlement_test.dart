// 檔案名稱：test/daycare_late_pickup_settlement_test.dart
// 功能說明：安親結算晚接回逾時、手動調整與最終應收下限

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

void main() {
  final DaycarePricingService pricing = DaycarePricingService.instance;
  const DaycareSettingsModel settings = DaycareSettingsModel(
    latePickupEnabled: true,
    overtimeGraceMinutes: 15,
    latePickupUnitMinutes: 30,
    latePickupPrice: 100,
  );
  final DateTime scheduledEnd = DateTime(2026, 9, 8, 18);

  test('實際接回未超時不加收', () {
    final DaycareLatePickupBreakdown pickup = pricing.latePickupBreakdown(
      settings: settings,
      scheduledEndAt: scheduledEnd,
      actualEndAt: DateTime(2026, 9, 8, 17, 50),
    );
    expect(pickup.extraMinutes, 0);
    expect(pickup.amount, 0);
    expect(pickup.formula, '未加收');
  });

  test('免費寬限內不加收', () {
    final DaycareLatePickupBreakdown pickup = pricing.latePickupBreakdown(
      settings: settings,
      scheduledEndAt: scheduledEnd,
      actualEndAt: DateTime(2026, 9, 8, 18, 10),
    );
    expect(pickup.extraMinutes, 10);
    expect(pickup.billableMinutes, 0);
    expect(pickup.amount, 0);
  });

  test('超過寬限 10 分鐘、每 30 分鐘 NT\$100 收 1 個單位', () {
    final DaycareLatePickupBreakdown pickup = pricing.latePickupBreakdown(
      settings: settings,
      scheduledEndAt: scheduledEnd,
      actualEndAt: DateTime(2026, 9, 8, 18, 25),
    );
    expect(pickup.extraMinutes, 25);
    expect(pickup.graceMinutes, 15);
    expect(pickup.billableMinutes, 10);
    expect(pickup.units, 1);
    expect(pickup.amount, 100);
    expect(pickup.formula, '1 個 30 分鐘 × NT\$100');
  });

  test('超過寬限 31 分鐘、每 30 分鐘 NT\$100 收 2 個單位', () {
    final DaycareLatePickupBreakdown pickup = pricing.latePickupBreakdown(
      settings: settings,
      scheduledEndAt: scheduledEnd,
      actualEndAt: DateTime(2026, 9, 8, 18, 46),
    );
    expect(pickup.extraMinutes, 46);
    expect(pickup.billableMinutes, 31);
    expect(pickup.units, 2);
    expect(pickup.amount, 200);
    expect(pickup.formula, '2 個 30 分鐘 × NT\$100');
  });

  test('跨日實際接回使用訂單時間，不拼成今天', () {
    final DateTime actualEnd = DateTime(2026, 9, 9, 18, 25);
    final DaycareLatePickupBreakdown pickup = pricing.latePickupBreakdown(
      settings: settings,
      scheduledEndAt: DateTime(2026, 9, 8, 18),
      actualEndAt: actualEnd,
    );
    expect(pickup.extraMinutes, 24 * 60 + 25);
    expect(actualEnd.year, 2026);
    expect(actualEnd.month, 9);
    expect(actualEnd.day, 9);
    expect(DaycareTimeHelper.formatDateTimeOrUnrecorded(null), '尚未記錄');
  });

  test('手動加價與減價，最終應收不低於 0', () {
    final DaycareSettlement plus = pricing.settle(
      settings: settings,
      booking: <String, dynamic>{
        'scheduledEndAt': scheduledEnd,
        'quotedTotalPrice': 1000,
        'paidAmount': 200,
      },
      actualEndAt: DateTime(2026, 9, 8, 18, 25),
      manualAdjust: 50,
    );
    expect(plus.overtimeAmount, 100);
    expect(plus.finalTotal, 1150);

    final DaycareSettlement minus = pricing.settle(
      settings: settings,
      booking: <String, dynamic>{
        'scheduledEndAt': scheduledEnd,
        'quotedTotalPrice': 1000,
        'paidAmount': 200,
      },
      actualEndAt: DateTime(2026, 9, 8, 18),
      manualAdjust: -1500,
    );
    expect(minus.overtimeAmount, 0);
    expect(minus.finalTotal, 0);
  });
}
