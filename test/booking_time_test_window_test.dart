import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/medication/booking_time_test_banner.dart';
import 'package:petnest_saas/features/medication/service_task_page.dart';

void main() {
  final start = DateTime.utc(2026, 11, 22, 14);
  final booking = <String, dynamic>{
    'shopId': 's',
    'bookingCode': 'TEST',
    'temporaryTimeTest': {
      'enabled': true,
      'bookingId': 'b',
      'bookingCode': 'TEST',
      'shopId': 's',
      'syncCustomer': true,
      'startedAt': start.toIso8601String(),
      'expiresAt': start.add(const Duration(hours: 2)).toIso8601String(),
    },
  };
  test('只限匹配訂單，兩小時到點前端立即恢復限制', () {
    expect(activeBookingTimeTest(booking, 'b', now: start), isNotNull);
    expect(activeBookingTimeTest(booking, 'other', now: start), isNull);
    expect(
      activeBookingTimeTest(
        booking,
        'b',
        now: start.add(const Duration(hours: 2)),
      ),
      isNull,
    );
  });
  test('測試期間可送未來時間，正常模式拒絕', () {
    final future = start.add(const Duration(hours: 1));
    expect(
      serviceActualTimeError(
        actual: future,
        checkIn: start,
        now: start,
        timeTest: true,
      ),
      isNull,
    );
    expect(
      serviceActualTimeError(actual: future, checkIn: start, now: start),
      contains('晚於現在'),
    );
  });
  test('永久模式只限指定測試單，隔天仍可用而其他單無法開通', () {
    const id = 'qcxaDmx9Qdn3W75LvGIP';
    final testOrder = <String, dynamic>{
      'shopId': 'SHOP0017',
      'bookingCode': 'SHOP0017-B000016',
      'temporaryTimeTest': {
        'mode': 'permanent',
        'enabled': true,
        'syncCustomer': true,
        'bookingId': id,
        'shopId': 'SHOP0017',
        'bookingCode': 'SHOP0017-B000016',
        'startedAt': start.toIso8601String(),
      },
    };
    expect(
      activeBookingTimeTest(
        testOrder,
        id,
        now: start.add(const Duration(days: 365)),
      ),
      isNotNull,
    );
    expect(activeBookingTimeTest(testOrder, 'other', now: start), isNull);
  });
}
