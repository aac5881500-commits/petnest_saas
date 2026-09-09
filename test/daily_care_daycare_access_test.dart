import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/services/daily_care_daycare_access.dart';
import 'package:petnest_saas/core/services/daily_care_record_service.dart';

void main() {
  test('daycare switch off hides fill access', () {
    const DailyCareSettingModel setting = DailyCareSettingModel();
    final Map<String, dynamic> booking = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'confirmed',
      'serviceDate': '2026-09-08',
    };
    expect(
      DailyCareDaycareAccess.canOperate(
        setting: setting,
        booking: booking,
        now: DateTime(2026, 9, 8, 10),
      ),
      isFalse,
    );
  });

  test('enabled daycare booking can fill 1 to 3 shared records', () {
    const DailyCareSettingModel setting = DailyCareSettingModel(
      daycareEnabled: true,
      daycareSessionCount: 3,
    );
    final Map<String, dynamic> booking = <String, dynamic>{
      'bookingKind': 'daycare',
      'status': 'confirmed',
      'serviceDate': '2026-09-08',
    };
    expect(
      DailyCareDaycareAccess.canOperate(
        setting: setting,
        booking: booking,
        now: DateTime(2026, 9, 8, 10),
      ),
      isTrue,
    );
    expect(setting.resolvedDaycareSessionLabels(), hasLength(3));
  });

  test('same-day daycare bookings use different record ids', () {
    final DateTime day = DateTime(2026, 9, 8);
    final String a = DailyCareRecordService.recordId(
      bookingId: 'dc_a',
      recordDate: day,
      sessionIndex: 0,
    );
    final String b = DailyCareRecordService.recordId(
      bookingId: 'dc_b',
      recordDate: day,
      sessionIndex: 0,
    );
    expect(a, isNot(b));
    expect(a, 'dc_a_20260908_0');
  });

  test('customer view is limited to daycare setting and non-cancelled', () {
    const DailyCareSettingModel setting = DailyCareSettingModel(
      daycareEnabled: true,
    );
    expect(
      DailyCareDaycareAccess.canCustomerView(
        setting: setting,
        booking: <String, dynamic>{
          'bookingKind': 'daycare',
          'status': 'confirmed',
        },
      ),
      isTrue,
    );
    expect(
      DailyCareDaycareAccess.canCustomerView(
        setting: setting,
        booking: <String, dynamic>{
          'bookingKind': 'daycare',
          'status': 'cancelled',
        },
      ),
      isFalse,
    );
  });

  test('legacy stay records without serviceType default to accommodation', () {
    final DailyCareRecordModel record = DailyCareRecordModel.fromMap(
      id: 'stay_1',
      map: <String, dynamic>{
        'shopId': 'shop',
        'bookingId': 'stay_booking',
        'roomId': 'r1',
        'sessionIndex': 0,
      },
    );
    expect(record.serviceType, DailyCareServiceTypes.accommodation);
    expect(record.bookingId, 'stay_booking');
  });
}
