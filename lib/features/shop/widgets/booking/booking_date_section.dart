// lib/features/shop/widgets/booking/booking_date_section.dart
// 🔥 前台預約日期區塊：顯示店名、預約狀態提示與選擇日期按鈕

import 'package:flutter/material.dart';

class BookingDateSection extends StatelessWidget {
  const BookingDateSection({
    super.key,
    required this.shopName,
    required this.bookingEnabled,
    required this.onOpenCalendar,
  });

  final String shopName;
  final bool bookingEnabled;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shopName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          bookingEnabled ? '請先從月曆選擇日期區間' : '目前店家暫停開放預約',
          style: TextStyle(
            color: bookingEnabled ? null : Colors.red,
          ),
        ),

        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: bookingEnabled ? onOpenCalendar : null,
          child: const Text('選擇日期'),
        ),
      ],
    );
  }
}