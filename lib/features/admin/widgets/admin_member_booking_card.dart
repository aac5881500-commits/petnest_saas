// lib/features/admin/widgets/admin_member_booking_card.dart
// 📦 後台會員詳細頁：會員訂單紀錄卡
//
// 用途：
// - 顯示會員的單筆訂單
// - 從會員詳細頁進入訂單詳細時固定唯讀，避免繞過訂單管理權限

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';

class AdminMemberBookingCard extends StatelessWidget {
  const AdminMemberBookingCard({
    super.key,
    required this.bookingId,
    required this.data,
  });

  final String bookingId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final start = (data['startDate'] as Timestamp).toDate();
    final end = (data['endDate'] as Timestamp).toDate();

    final status = data['status']?.toString() ?? '';
    final depositPaid = data['depositPaid'] == true;
    final totalPrice = data['totalPrice'] ?? 0;
    final depositAmount = data['depositAmount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminBookingDetailPage(
                bookingId: bookingId,
                canEdit: false,
              ),
            ),
          );
        },
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.hotel, color: Colors.orange),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['roomName'] ?? '房型',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _statusBadge(status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${start.year}-${start.month}-${start.day} ～ ${end.year}-${end.month}-${end.day}',
              ),
              const SizedBox(height: 4),
              Text(
                'NT\$ $totalPrice｜訂金 NT\$ $depositAmount',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                depositPaid ? '已付訂金' : '尚未確認訂金',
                style: TextStyle(
                  color: depositPaid ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _statusBadge(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}