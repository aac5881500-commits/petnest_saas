import 'package:flutter/material.dart';

import '../models/booking_medication_task.dart';
import '../services/booking_service.dart';
import '../services/shop_task_center_service.dart';
import 'booking_care_activity.dart';

/// The booking is the source of truth, including corrections made after a report.
class DailyCareMedicationSummary extends StatelessWidget {
  const DailyCareMedicationSummary({
    super.key,
    required this.booking,
    required this.dateKey,
    this.includePending = false,
  });

  final Map<String, dynamic> booking;
  final String dateKey;
  final bool includePending;

  @override
  Widget build(BuildContext context) {
    return BookingCareActivity(
      bookingId: '${booking['bookingId'] ?? ''}',
      booking: booking,
      dateKey: dateKey,
      recordedOnly: !includePending,
    );
  }
}

class StaffDailyCareMedicationSummary extends StatefulWidget {
  const StaffDailyCareMedicationSummary({
    super.key,
    required this.bookingId,
    required this.recordDate,
  });

  final String bookingId;
  final DateTime recordDate;

  @override
  State<StaffDailyCareMedicationSummary> createState() =>
      _StaffDailyCareMedicationSummaryState();
}

class _StaffDailyCareMedicationSummaryState
    extends State<StaffDailyCareMedicationSummary> {
  late final _booking = BookingService.instance.streamBooking(widget.bookingId);

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: _booking,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Text('照護時程讀取失敗，請重新開啟回報');
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return _StaffCareActions(
        booking: snapshot.data!,
        bookingId: widget.bookingId,
        dateKey: BookingMedicationTask.dateKey(widget.recordDate),
      );
    },
  );
}

class _StaffCareActions extends StatefulWidget {
  const _StaffCareActions({
    required this.booking,
    required this.bookingId,
    required this.dateKey,
  });
  final Map<String, dynamic> booking;
  final String bookingId, dateKey;
  @override
  State<_StaffCareActions> createState() => _StaffCareActionsState();
}

class _StaffCareActionsState extends State<_StaffCareActions> {
  late final _access = ShopTaskCenterService.instance.loadAccess(
    '${widget.booking['shopId']}',
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<ShopTaskAccess>(
    future: _access,
    builder: (context, snapshot) => BookingCareActivity(
      bookingId: widget.bookingId,
      booking: widget.booking,
      dateKey: widget.dateKey,
      staff: snapshot.data?.canViewBookings == true,
    ),
  );
}
