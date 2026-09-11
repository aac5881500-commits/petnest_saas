// 檔案名稱：test/daycare_time_slot_test.dart
// 功能說明：安親今日時段不可選過去、超過最晚接回整天關閉

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_booking_validator.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

void main() {
  test('今天中午 12:00（台灣）時，12:00 前不可選、之後可選', () {
    final DateTime date = DateTime(2026, 9, 7);
    final DateTime now = DateTime.utc(2026, 9, 7, 4, 0);
    expect(
      DaycareTimeHelper.isSlotSelectable(slot: '11:30', date: date, now: now),
      isFalse,
    );
    expect(
      DaycareTimeHelper.isSlotSelectable(slot: '12:00', date: date, now: now),
      isFalse,
    );
    expect(
      DaycareTimeHelper.isSlotSelectable(slot: '12:30', date: date, now: now),
      isTrue,
    );
  });

  test('15:10 時今天 15:00 含以前不可選，15:30 可選', () {
    final DateTime date = DateTime(2026, 9, 7);
    final DateTime now = DateTime.utc(2026, 9, 7, 7, 10);
    expect(
      DaycareTimeHelper.isSlotSelectable(slot: '15:00', date: date, now: now),
      isFalse,
    );
    expect(
      DaycareTimeHelper.isSlotSelectable(slot: '15:30', date: date, now: now),
      isTrue,
    );
  });

  test('明天上午不受現在時刻影響', () {
    final DateTime date = DateTime(2026, 9, 8);
    final DateTime now = DateTime.utc(2026, 9, 7, 7, 10);
    expect(
      DaycareTimeHelper.isSlotSelectable(slot: '09:00', date: date, now: now),
      isTrue,
    );
  });

  test('接回不可早於或等於送達', () {
    final DateTime date = DateTime(2026, 9, 8);
    final DateTime now = DateTime(2026, 9, 7, 10, 0);
    expect(
      DaycareTimeHelper.isSlotSelectable(
        slot: '14:00',
        date: date,
        now: now,
        afterSlot: '14:00',
      ),
      isFalse,
    );
    expect(
      DaycareTimeHelper.isSlotSelectable(
        slot: '14:30',
        date: date,
        now: now,
        afterSlot: '14:00',
      ),
      isTrue,
    );
  });

  test('現在已過最晚接回，今天整天不可預約', () {
    expect(
      DaycareTimeHelper.isTodayPastLatestPickUp(
        date: DateTime(2026, 9, 7),
        latestPickUp: '19:00',
        now: DateTime(2026, 9, 7, 20, 54),
      ),
      isTrue,
    );
    const DaycareSettingsModel settings = DaycareSettingsModel(
      earliestDropOff: '09:00',
      latestPickUp: '19:00',
      allowSameDay: true,
    );
    final DaycareValidationResult result =
        DaycareBookingValidator.validateSchedule(
          settings: settings,
          startAt: DateTime(2026, 9, 7, 10, 0),
          endAt: DateTime(2026, 9, 7, 18, 0),
          now: DateTime(2026, 9, 7, 20, 54),
        );
    expect(result.isOk, isFalse);
    expect(result.error, contains('今日已超過最晚接回時間'));
  });
}
