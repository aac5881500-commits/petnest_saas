// lib/features/admin/widgets/booking_status_filter.dart
// 🏷️ 後台訂單狀態篩選膠囊
//
// 功能：
// - 顯示訂單狀態篩選按鈕
// - 顯示各狀態數量
// - 點擊後回傳目前選擇的 filterType

import 'package:flutter/material.dart';

class BookingStatusFilter extends StatelessWidget {
  const BookingStatusFilter({
    super.key,
    required this.selectedType,
    required this.counts,
    required this.onChanged,
  });

  final String selectedType;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
  _FilterItem('pending', '待確認', Colors.orange),
  _FilterItem('depositReview', '已回傳付款/訂金', Colors.red),
  _FilterItem('confirmed', '已確認', Colors.blue),
  _FilterItem('checked_in', '入住中', Colors.green),
  _FilterItem('todayCheckIn', '今日入住', Colors.deepPurple),
  _FilterItem('todayCheckOut', '今日退房', Colors.lightBlue),
  _FilterItem('futureCheckIn', '未來入住', Colors.teal),
  _FilterItem('history', '歷史查詢', Colors.grey),
];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          final selected = selectedType == item.type;
          final count = counts[item.type] ?? 0;

          return GestureDetector(
            onTap: () => onChanged(item.type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? item.color
                    : item.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : item.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: selected ? Colors.white : item.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterItem {
  const _FilterItem(
    this.type,
    this.label,
    this.color,
  );

  final String type;
  final String label;
  final Color color;
}