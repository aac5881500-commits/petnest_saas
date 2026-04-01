// lib/features/member/pages/member_booking_page.dart
// 📦 會員訂單列表頁

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_detail_page.dart';

class MemberBookingPage extends StatelessWidget {
  const MemberBookingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('請先登入')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的訂單'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('尚無訂單'));
          }

          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final start =
                  (data['startDate'] as Timestamp).toDate();
              final end =
                  (data['endDate'] as Timestamp).toDate();

              final status = data['status'] ?? 'pending';

              String statusText;
              Color statusColor;

              switch (status) {
                case 'confirmed':
                  statusText = '已確認';
                  statusColor = Colors.green;
                  break;
                case 'checked_in':
                  statusText = '入住中';
                  statusColor = Colors.blue;
                  break;
                case 'completed':
                  statusText = '已完成';
                  statusColor = Colors.grey;
                  break;
                case 'cancelled':
                  statusText = '已取消';
                  statusColor = Colors.red;
                  break;
                default:
                  statusText = '待確認';
                  statusColor = Colors.orange;
              }

              return Card(
                child: ListTile(
                  title: Text(data['roomName'] ?? '房型'),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatDate(start)} ～ ${_formatDate(end)}',
                      ),
                      const SizedBox(height: 4),

                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

trailing: Builder(
  builder: (_) {
    final canCancel =
        status == 'pending' || status == 'confirmed';

    if (!canCancel) return const SizedBox();

    return TextButton(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('確認取消訂單'),
            content: const Text('確定要取消這筆預約嗎？'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('否'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(context, true),
                child: const Text('是'),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        final user = FirebaseAuth.instance.currentUser;

await FirebaseFirestore.instance
    .collection('bookings')
    .doc(doc.id)
    .update({
  'status': 'cancelled',
});

/// 🔥 記錄操作
await FirebaseFirestore.instance
    .collection('action_logs')
    .add({
  'type': 'booking_cancel',
  'bookingId': doc.id,
  'operatorUid': user?.uid,
  'operatorRole': 'customer',
  'createdAt': FieldValue.serverTimestamp(),
});
      },
      child: const Text(
        '取消',
        style: TextStyle(color: Colors.red),
      ),
    );
  },
),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminBookingDetailPage(
                          bookingId: doc.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}