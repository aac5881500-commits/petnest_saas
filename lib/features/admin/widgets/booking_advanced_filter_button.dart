// 檔案名稱：lib/features/admin/widgets/booking_advanced_filter_button.dart
// 功能說明：後台訂單進階篩選按鈕
// 功能：
// - 顯示進階篩選入口
// - 預留之後日期 / 房型 / 付款狀態篩選

import 'package:flutter/material.dart';

class BookingAdvancedFilterButton extends StatelessWidget {
  const BookingAdvancedFilterButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.tune, size: 16, color: Colors.grey),
            SizedBox(width: 6),
            Text(
              '篩選',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
