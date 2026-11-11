import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daily_care_date_helper.dart';
import 'package:petnest_saas/core/services/daily_care_daycare_access.dart';

/// A read-only task projection. Completion remains in the original order flow.
DateTime? workbenchBookingTaskDate(
  Map<String, dynamic> booking, {
  required bool departure,
}) {
  if (BookingKind.isDaycare(booking)) {
    return DailyCareDaycareAccess.serviceCalendarDate(booking);
  }
  final raw = booking[departure ? 'endDate' : 'startDate'];
  final instant = raw is Timestamp
      ? raw.toDate()
      : raw is DateTime
      ? raw
      : null;
  return instant == null
      ? null
      : DailyCareDateHelper.calendarDateInTaipei(instant);
}
