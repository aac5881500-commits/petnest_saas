// 檔案名稱：lib/features/admin/widgets/admin_booking_action_log_section.dart
// 功能說明：讀取 action_logs 並顯示此訂單的操作紀錄列表
// 📝 後台訂單詳細頁：操作紀錄區塊

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_log_card.dart';

class AdminBookingActionLogSection extends StatelessWidget {
  const AdminBookingActionLogSection({
    super.key,
    required this.shopId,
    required this.bookingId,
  });

  final String shopId;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('action_logs')
            .where('shopId', isEqualTo: shopId)
            .where('bookingId', isEqualTo: bookingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              '操作紀錄讀取失敗：${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data?.docs ?? [];

          if (logs.isEmpty) {
            return const Text('目前無操作紀錄', style: TextStyle(color: Colors.grey));
          }

          return Column(
            children: logs.map((doc) {
              final log = doc.data() as Map<String, dynamic>;
              return AdminBookingActionLogCard(log: log);
            }).toList(),
          );
        },
      ),
    );
  }
}
