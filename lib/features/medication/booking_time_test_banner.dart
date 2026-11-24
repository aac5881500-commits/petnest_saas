import 'dart:async';
import 'package:flutter/material.dart';

DateTime? activeBookingTimeTest(
  Map<String, dynamic> booking,
  String bookingId, {
  DateTime? now,
}) {
  final raw = booking['temporaryTimeTest'];
  if (raw is! Map ||
      raw['enabled'] != true ||
      raw['bookingId'] != bookingId ||
      raw['shopId'] != booking['shopId'] ||
      raw['bookingCode'] != booking['bookingCode'] ||
      raw['syncCustomer'] != true) {
    return null;
  }
  final from = DateTime.tryParse('${raw['startedAt']}');
  final until = DateTime.tryParse('${raw['expiresAt']}');
  final current = now ?? DateTime.now();
  if (raw['mode'] == 'permanent') {
    return bookingId == 'qcxaDmx9Qdn3W75LvGIP' &&
            booking['shopId'] == 'SHOP0017' &&
            booking['bookingCode'] == 'SHOP0017-B000016' &&
            from != null &&
            !current.isBefore(from)
        ? DateTime.utc(9999)
        : null;
  }
  if (from == null ||
      until == null ||
      !until.isAfter(from) ||
      until.difference(from) > const Duration(hours: 2) ||
      current.isBefore(from) ||
      !current.isBefore(until)) {
    return null;
  }
  return until;
}

class BookingTimeTestBanner extends StatefulWidget {
  const BookingTimeTestBanner({
    super.key,
    required this.booking,
    required this.bookingId,
  });
  final Map<String, dynamic> booking;
  final String bookingId;
  @override
  State<BookingTimeTestBanner> createState() => _BookingTimeTestBannerState();
}

class _BookingTimeTestBannerState extends State<BookingTimeTestBanner> {
  Timer? timer;
  void syncTimer() {
    timer?.cancel();
    if ((widget.booking['temporaryTimeTest'] as Map?)?['mode'] != 'permanent' &&
        activeBookingTimeTest(widget.booking, widget.bookingId) != null) {
      timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
        if (activeBookingTimeTest(widget.booking, widget.bookingId) == null) {
          timer?.cancel();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    syncTimer();
  }

  @override
  void didUpdateWidget(covariant BookingTimeTestBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.booking['temporaryTimeTest'] is! Map) {
      return const SizedBox.shrink();
    }
    final until = activeBookingTimeTest(widget.booking, widget.bookingId);
    final taipei = until?.toUtc().add(const Duration(hours: 8));
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        until != null &&
                (widget.booking['temporaryTimeTest'] as Map)['mode'] ==
                    'permanent'
            ? '專用測試訂單・不自動關閉\n僅此訂單可提前填寫並真正儲存，結果會同步給飼主並保留測試標記。'
            : taipei == null
            ? '限時測試已結束，已恢復正常時間限制。'
            : '限時測試中・僅此訂單\n${taipei.month}/${taipei.day} ${taipei.hour.toString().padLeft(2, '0')}:${taipei.minute.toString().padLeft(2, '0')}（台灣時間）自動關閉\n可提前填寫並真正儲存，結果會同步給飼主並保留測試標記。',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
