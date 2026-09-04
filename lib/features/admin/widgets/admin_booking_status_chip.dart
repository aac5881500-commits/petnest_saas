// lib/features/admin/widgets/admin_booking_status_chip.dart
// 🏷️ 後台訂單詳細頁：訂單狀態標籤
// 功能：依照訂單 status 顯示不同顏色與中文狀態

import 'package:flutter/material.dart';

class AdminBookingStatusChip extends StatelessWidget {
  const AdminBookingStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case 'confirmed':
        color = Colors.green;
        text = '已確認';
        break;
      case 'checked_in':
        color = Colors.blue;
        text = '入住中';
        break;
      case 'completed':
        color = Colors.grey;
        text = '已完成';
        break;
      case 'cancelled':
        color = Colors.red;
        text = '已取消';
        break;
      default:
        color = Colors.orange;
        text = '待確認';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

String adminBookingStatusText(dynamic value) {
  switch (value) {
    case 'pending':
      return '待確認';
    case 'confirmed':
      return '已確認';
    case 'checked_in':
      return '入住中';
    case 'completed':
      return '已完成';
    case 'cancelled':
      return '已取消';
    default:
      return value?.toString() ?? '-';
  }
}
