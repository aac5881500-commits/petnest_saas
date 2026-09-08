// 檔案名稱：lib/core/widgets/booking_payment_deadline_banner.dart
// 功能說明：住宿／安親共用付款期限與即時倒數（不自動取消訂單）

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class BookingPaymentDeadlineBanner extends StatefulWidget {
  const BookingPaymentDeadlineBanner({
    super.key,
    required this.data,
    this.title = '付款期限',
  });

  final Map<String, dynamic> data;
  final String title;

  @override
  State<BookingPaymentDeadlineBanner> createState() =>
      _BookingPaymentDeadlineBannerState();
}

class _BookingPaymentDeadlineBannerState
    extends State<BookingPaymentDeadlineBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!BookingPaymentStatus.showPaymentDeadline(widget.data)) {
      return const SizedBox.shrink();
    }
    final DateTime? expireAt = SafeParse.parseDate(
      widget.data['depositExpireAt'],
    );
    if (expireAt == null) {
      return const SizedBox.shrink();
    }
    final bool overdue = BookingPaymentStatus.isDeadlineOverdue(widget.data);
    final String when = _format(expireAt);
    final String count = BookingPaymentStatus.countdownLabel(expireAt);
    final Color color = overdue ? Colors.red.shade800 : Colors.red.shade700;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: overdue ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: overdue ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            overdue ? '${widget.title}已逾期' : widget.title,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            when,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    final String h = value.hour.toString().padLeft(2, '0');
    final String min = value.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }
}
