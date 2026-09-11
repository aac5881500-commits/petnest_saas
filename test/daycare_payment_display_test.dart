// 檔案名稱：test/daycare_payment_display_test.dart
// 功能說明：安親付款顯示與 pricingMode／分房限制單元測試

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_assign_room_rules.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';

void main() {
  group('DaycarePaymentDisplay', () {
    test('新訂單總額 400、未付款時顯示完整尾款', () {
      const Map<String, dynamic> data = <String, dynamic>{
        'totalPrice': 400,
        'paidAmount': 0,
        'remainingAmount': 0,
        'paymentStatus': 'paid',
      };
      final int total = DaycarePaymentDisplay.resolveTotal(data);
      final int paid = DaycarePaymentDisplay.resolvePaid(data);
      final int remaining = DaycarePaymentDisplay.resolveRemaining(
        total: total,
        paid: paid,
      );
      expect(total, 400);
      expect(paid, 0);
      expect(remaining, 400);
      expect(
        DaycarePaymentDisplay.isFullyPaid(
          total: total,
          paid: paid,
          remaining: remaining,
        ),
        isFalse,
      );
      expect(
        DaycarePaymentDisplay.statusLabel(
          total: total,
          paid: paid,
          remaining: remaining,
        ),
        '未付款',
      );
    });

    test('root 總額缺漏時改用 pricingSnapshot', () {
      const Map<String, dynamic> data = <String, dynamic>{
        'totalAmount': 0,
        'totalPrice': 0,
        'paidAmount': 0,
        'daycarePricingSnapshot': <String, dynamic>{'totalAmount': 400},
      };
      expect(DaycarePaymentDisplay.resolveTotal(data), 400);
    });

    test('已完全付款才顯示已付清', () {
      const Map<String, dynamic> data = <String, dynamic>{
        'totalPayableAmount': 400,
        'paidAmount': 400,
      };
      final int total = DaycarePaymentDisplay.resolveTotal(data);
      final int paid = DaycarePaymentDisplay.resolvePaid(data);
      final int remaining = DaycarePaymentDisplay.resolveRemaining(
        total: total,
        paid: paid,
      );
      expect(
        DaycarePaymentDisplay.isFullyPaid(
          total: total,
          paid: paid,
          remaining: remaining,
        ),
        isTrue,
      );
      expect(
        DaycarePaymentDisplay.statusLabel(
          total: total,
          paid: paid,
          remaining: remaining,
        ),
        '已付清',
      );
    });
  });

  group('DaycarePricingModes', () {
    test('相容 room_based／roomType／room_type', () {
      expect(DaycarePricingModes.isRoomBased('room_based'), isTrue);
      expect(DaycarePricingModes.isRoomBased('roomType'), isTrue);
      expect(DaycarePricingModes.isRoomBased('room_type'), isTrue);
      expect(DaycarePricingModes.isRoomBased('time_based'), isFalse);
      expect(DaycarePricingModes.isRoomBased('independentPlan'), isFalse);
      expect(DaycarePricingModes.isRoomBased('independent'), isFalse);
      expect(DaycarePricingModes.isRoomBased('hourly'), isFalse);
    });
  });

  group('DaycareAssignRoomRules', () {
    test('房型計費不可改成其他房型', () {
      const Map<String, dynamic> booking = <String, dynamic>{
        'pricingMode': 'room_based',
        'requestedRoomTypeId': 'typeA',
      };
      expect(DaycareAssignRoomRules.lockRoomType(booking), isTrue);
      expect(
        DaycareAssignRoomRules.allowsAssignedRoomType(
          booking: booking,
          assignedRoomTypeId: 'typeA',
        ),
        isTrue,
      );
      expect(
        DaycareAssignRoomRules.allowsAssignedRoomType(
          booking: booking,
          assignedRoomTypeId: 'typeB',
        ),
        isFalse,
      );
    });

    test('獨立方案可選任何房型', () {
      const Map<String, dynamic> booking = <String, dynamic>{
        'pricingMode': 'independentPlan',
        'requestedRoomTypeId': '',
      };
      expect(DaycareAssignRoomRules.lockRoomType(booking), isFalse);
      expect(
        DaycareAssignRoomRules.allowsAssignedRoomType(
          booking: booking,
          assignedRoomTypeId: 'anyType',
        ),
        isTrue,
      );
    });
  });

  test('安親狀態顯示中文且 No-show 不顯示 raw', () {
    expect(
      DaycareStatusLabels.primary(<String, dynamic>{'status': 'pending'}),
      '待確認',
    );
    expect(
      DaycareStatusLabels.primary(<String, dynamic>{
        'status': 'pending_confirmation',
      }),
      '待確認',
    );
    expect(
      DaycareStatusLabels.primary(<String, dynamic>{'status': 'checked_in'}),
      '安親中',
    );
    expect(
      DaycareStatusLabels.primary(<String, dynamic>{
        'status': 'cancelled',
        'noShow': true,
      }),
      '已取消',
    );
    expect(
      DaycareStatusLabels.primary(<String, dynamic>{'status': 'assigned'}),
      '已分房',
    );
    expect(
      DaycareStatusLabels.assignLabel(<String, dynamic>{
        'assignStatus': 'unassigned',
      }),
      '尚未分房',
    );
  });
}
