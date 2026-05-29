// lib/features/admin/widgets/admin_booking_action_log_card.dart
// 📝 後台訂單詳細頁：操作紀錄卡片
// 功能：顯示訂單操作紀錄、操作者、操作時間與狀態變更內容

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_status_chip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_text_helpers.dart';

class AdminBookingActionLogCard extends StatelessWidget {
  const AdminBookingActionLogCard({
    super.key,
    required this.log,
  });

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final type = log['type'] ?? '';
    final time = adminBookingFormatDateTime(log['createdAt']);
    final operatorEmail = log['operatorEmail'];

    final operatorText = operatorEmail != null &&
            operatorEmail.toString().isNotEmpty
        ? operatorEmail.toString()
        : adminBookingOperatorRoleText(log['operatorRole']);

    String title = '操作紀錄';

    if (type == 'booking_status_update') {
      title =
          '狀態變更：'
          '${adminBookingStatusText(log['fromStatus'])}'
          ' → '
          '${adminBookingStatusText(log['toStatus'])}';
    } else if (type == 'deposit_confirmed') {
      title = '確認收到訂金';
    } else if (type == 'booking_cancelled') {
      title = '取消訂單：${log['cancelReason'] ?? '-'}';
    } else if (type == 'checkout_completed') {
      title = '退房完成：額外費用 NT\$ ${log['extraFee'] ?? 0}';
    } else if (type == 'room_assigned') {
      title = '完成分房：${log['roomName'] ?? '-'}';
    } else if (type == 'room_changed') {
      final reason = (log['reason'] ?? '').toString();

      title =
          '更換房間：${log['oldRoomName'] ?? '-'} → ${log['newRoomName'] ?? '-'}';

      if (reason.isNotEmpty) {
        title += '\n原因：$reason';
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$time ・ 操作者：$operatorText',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}