// 檔案名稱：test/booking_order_type_test.dart
// 功能說明：三種訂單類型與舊資料 fallback。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/booking_order_type.dart';

void main() {
  test('舊住宿無 bookingKind 仍判為住宿', () {
    expect(
      BookingOrderType.resolve(const <String, dynamic>{
        'startDate': '2026-09-01',
        'roomTypeName': 'VIP',
        'nights': 2,
      }),
      BookingOrderType.accommodation,
    );
  });

  test('依房型安親', () {
    expect(
      BookingOrderType.resolve(const <String, dynamic>{
        'bookingKind': 'daycare',
        'pricingMode': 'roomType',
        'requestedRoomTypeId': 'vip',
      }),
      BookingOrderType.daycareRoomType,
    );
  });

  test('獨立時計安親', () {
    expect(
      BookingOrderType.resolve(const <String, dynamic>{
        'bookingKind': 'daycare',
        'pricingMode': 'independentPlan',
        'daycarePlanId': 'hourly',
      }),
      BookingOrderType.daycareIndependentPlan,
    );
  });

  test('安親缺欄位時為未知', () {
    expect(
      BookingOrderType.resolve(const <String, dynamic>{
        'bookingKind': 'daycare',
      }),
      BookingOrderType.unknown,
    );
    expect(BookingOrderType.label(BookingOrderType.unknown), '未知訂單類型');
  });
}
