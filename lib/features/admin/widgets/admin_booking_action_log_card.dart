// 檔案名稱：lib/features/admin/widgets/admin_booking_action_log_card.dart
// 功能說明：顯示訂單操作紀錄、操作者、操作時間與狀態變更內容
// 📝 後台訂單詳細頁：操作紀錄卡片

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/core/services/operator_display.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_status_chip.dart';

class AdminBookingActionLogCard extends StatelessWidget {
  const AdminBookingActionLogCard({super.key, required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final type = (log['type'] ?? log['action'] ?? '').toString();
    final String time = _formatTime(log['createdAt']);

    String title = '操作紀錄';
    final String daycareTitle = DaycareStatusLabels.actionName(type);
    if (daycareTitle.isNotEmpty) {
      title = daycareTitle;
      final dynamic payload = log['payload'];
      if (payload is Map && (payload['roomName'] ?? '').toString().isNotEmpty) {
        title = '$daycareTitle：${payload['roomName']}';
      }
    } else if (type == 'booking_status_update') {
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            child: Row(
              children: <Widget>[
                Text('$time ・ 操作人員：'),
                Flexible(
                  child: OperatorActorLabel(
                    shopId: (log['shopId'] ?? '').toString(),
                    log: log,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(dynamic value) {
    if (value is Timestamp) {
      return DaycareTimeHelper.formatDateTime(value.toDate());
    }
    if (value is DateTime) {
      return DaycareTimeHelper.formatDateTime(value);
    }
    return adminBookingFormatDateTime(value);
  }
}
