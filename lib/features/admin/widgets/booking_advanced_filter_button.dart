// lib/features/admin/widgets/booking_advanced_filter_button.dart
// 🎚️ 後台訂單進階篩選按鈕
//
// 功能：
// - 顯示進階篩選入口
// - 預留之後日期 / 房型 / 付款狀態篩選

import 'package:flutter/material.dart';

class BookingAdvancedFilterButton extends StatelessWidget {
  const BookingAdvancedFilterButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100.withOpacity(0.65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  '進階篩選',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
