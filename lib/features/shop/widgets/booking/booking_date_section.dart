// lib/features/shop/widgets/booking/booking_date_section.dart
// 🔥 前台預約日期區塊：顯示店名、預約狀態提示、已選日期與選擇日期按鈕

import 'package:flutter/material.dart';

class BookingDateSection extends StatelessWidget {
  const BookingDateSection({
    super.key,
    required this.shopName,
    required this.bookingEnabled,
    required this.onOpenCalendar,
    this.startDate,
    this.endDate,
    this.nights = 0,
  });

  final String shopName;
  final bool bookingEnabled;
  final VoidCallback onOpenCalendar;
  final DateTime? startDate;
  final DateTime? endDate;
  final int nights;

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final hasDate = startDate != null && endDate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shopName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          bookingEnabled ? '請先從月曆選擇日期區間' : '目前店家暫停開放預約',
          style: TextStyle(color: bookingEnabled ? null : Colors.red),
        ),

        const SizedBox(height: 8),

        ElevatedButton.icon(
          onPressed: bookingEnabled ? onOpenCalendar : null,
          icon: const Icon(Icons.calendar_month, size: 18),
          label: Text(
            hasDate
                ? '${_formatDate(startDate!)} ～ ${_formatDate(endDate!)}｜共 $nights 晚'
                : '選擇日期',
          ),
        ),
      ],
    );
  }
}
