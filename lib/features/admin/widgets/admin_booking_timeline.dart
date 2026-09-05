// 檔案名稱：lib/features/admin/widgets/admin_booking_timeline.dart
// 功能說明：顯示預約送出、付款期限、確認、入住、退房完成、取消/完成狀態
// 🕒 後台訂單詳細頁：訂單時間軸

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';

class AdminBookingTimeline extends StatelessWidget {
  const AdminBookingTimeline({
    super.key,
    required this.data,
    required this.status,
    required this.depositRequired,
  });

  final Map<String, dynamic> data;
  final String status;
  final bool depositRequired;

  @override
  Widget build(BuildContext context) {
    final depositAmount = data['depositAmount'] ?? 0;
    final paymentMethod = data['paymentMethod']?.toString() ?? '';
    final hasDeposit =
        depositAmount > 0 &&
        (paymentMethod == 'transfer' || paymentMethod == 'cash');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _timelineItem(
            title: '已送出預約',
            time: adminBookingFormatDateTime(data['createdAt']),
            active: true,
          ),

          if (hasDeposit) ...[
            _timelineItem(
              title: '付款 / 訂單保留期限',
              time: adminBookingFormatDateTime(data['depositExpireAt']),
              active: data['depositExpireAt'] != null,
            ),

            _timelineItem(
              title: '客戶已回傳付款資料',
              time: adminBookingFormatDateTime(data['depositSubmittedAt']),
              active: data['depositSubmittedAt'] != null,
            ),
          ],

          _timelineItem(
            title: '店家已確認',
            time: adminBookingFormatDateTime(data['confirmedAt']),
            active: data['confirmedAt'] != null,
          ),

          _timelineItem(
            title: '入住',
            time: adminBookingFormatDateTime(data['checkInAt']),
            active: data['checkInAt'] != null,
          ),

          _timelineItem(
            title: '退房完成',
            time: adminBookingFormatDateTime(data['checkOutAt']),
            active: data['checkOutAt'] != null,
          ),

          if (status == 'cancelled')
            _timelineItem(
              title: '訂單已取消',
              time: adminBookingFormatDateTime(data['cancelledAt']),
              active: true,
              isLast: true,
            )
          else
            _timelineItem(
              title: '訂單完成',
              time: adminBookingFormatDateTime(data['checkOutAt']),
              active: status == 'completed',
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _timelineItem({
    required String title,
    required String time,
    required bool active,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: active ? Colors.green : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: active
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(width: 2, height: 38, color: Colors.grey.shade300),
          ],
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.blue.shade700 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
