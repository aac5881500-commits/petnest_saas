// 檔案名稱：lib/features/admin/widgets/admin_booking_action_log_card.dart
// 功能說明：顯示訂單操作紀錄、操作者、操作時間與狀態變更內容
// 📝 後台訂單詳細頁：操作紀錄卡片

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_action_log_display.dart';
import 'package:petnest_saas/core/services/operator_display.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_room_name_lookup.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';

class AdminBookingActionLogCard extends StatelessWidget {
  const AdminBookingActionLogCard({
    super.key,
    required this.log,
    this.shopId = '',
  });

  final Map<String, dynamic> log;
  final String shopId;

  @override
  Widget build(BuildContext context) {
    final String resolvedShopId = (log['shopId'] ?? shopId).toString().trim();
    final Set<String> roomIds = BookingActionLogDisplay.roomIdsNeedingLookup(
      log,
    );
    if (roomIds.isEmpty || resolvedShopId.isEmpty) {
      return _card(BookingActionLogDisplay.detailLines(log), resolvedShopId);
    }
    return FutureBuilder<Map<String, String>>(
      future: ShopRoomNameLookup.resolve(
        shopId: resolvedShopId,
        roomIds: roomIds,
      ),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, String>> snapshot) {
            return _card(
              BookingActionLogDisplay.detailLines(
                log,
                roomNames: snapshot.data ?? const <String, String>{},
                awaitingRoomNames:
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData,
              ),
              resolvedShopId,
            );
          },
    );
  }

  Widget _card(List<String> details, String resolvedShopId) {
    final String title = BookingActionLogDisplay.title(log);
    final String time = _formatTime(log['createdAt'] ?? log['operatedAt']);

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
          for (final String line in details) ...<Widget>[
            const SizedBox(height: 4),
            Text(line, style: const TextStyle(fontSize: 13, height: 1.35)),
          ],
          const SizedBox(height: 6),
          DefaultTextStyle(
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$time ・ 操作人員：'),
                Flexible(
                  child: OperatorActorLabel(shopId: resolvedShopId, log: log),
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
