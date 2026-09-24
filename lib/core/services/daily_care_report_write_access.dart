// 檔案名稱：lib/core/services/daily_care_report_write_access.dart
// 功能說明：依既有訂單 status／結算欄位判斷每日回報是否可寫入（前後端共用條件）。

import 'booking_settlement_math.dart';
import 'daily_care_daycare_access.dart';

class DailyCareReportWriteAccess {
  DailyCareReportWriteAccess._();

  static const String lockedMessage = '訂單已結清，回報已鎖定';

  static const Set<String> _blockedStatuses = <String>{
    'cancelled',
    'no_show',
    'rejected',
    'expired',
    'refused',
    'checked_out',
    'completed',
  };

  static String statusOf(Map<String, dynamic>? booking) {
    return (booking?['status'] ?? '').toString().trim();
  }

  /// 住宿／安親已退房、已接回、已結清、已完成，或取消等不可填寫狀態。
  static bool isLocked(Map<String, dynamic>? booking) {
    if (booking == null || booking.isEmpty) {
      return true;
    }
    final String status = statusOf(booking);
    if (status.isEmpty) {
      return true;
    }
    if (_blockedStatuses.contains(status)) {
      return true;
    }
    if (BookingSettlementMath.isSettlementConfirmed(booking)) {
      return true;
    }
    return false;
  }

  /// 僅入住中／安親進行中（checked_in）且尚未結清時可寫入。
  static bool canWrite(Map<String, dynamic>? booking) {
    if (booking == null || booking.isEmpty) {
      return false;
    }
    if (isLocked(booking)) {
      return false;
    }
    return statusOf(booking) == 'checked_in';
  }

  static bool canWriteDaycare(Map<String, dynamic>? booking) {
    if (!canWrite(booking)) {
      return false;
    }
    return DailyCareDaycareAccess.hasStartedCare(booking!);
  }
}
