// lib/features/admin/pages/admin_dashboard_page.dart
// 📊 店家首頁 Dashboard

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/pages/admin_booking_list_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('店家後台'),
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
_buildCard(context, '今日入住', stats['checkIn'] ?? 0, Colors.blue, 'checkIn'),
_buildCard(context, '今日退房', stats['checkOut'] ?? 0, Colors.orange, 'checkOut'),
_buildCard(context, '未來訂單', stats['future'] ?? 0, Colors.green, 'future'),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 🔥 載入統計
  Future<Map<String, int>> _loadStats() async {
    final now = DateTime.now();

    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .get();

    int checkIn = 0;
    int checkOut = 0;
    int future = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final start = (data['startDate'] as Timestamp).toDate();
      final end = (data['endDate'] as Timestamp).toDate();
      final status = data['status'] ?? '';

      if (status == 'cancelled') continue;

      /// 今日入住
      if (start.isAfter(todayStart) && start.isBefore(todayEnd)) {
        checkIn++;
      }

      /// 今日退房
      if (end.isAfter(todayStart) && end.isBefore(todayEnd)) {
        checkOut++;
      }

      /// 未來訂單
      if (start.isAfter(todayEnd)) {
        future++;
      }
    }

    return {
      'checkIn': checkIn,
      'checkOut': checkOut,
      'future': future,
    };
  }

  Widget _buildCard(
  BuildContext context,
  String title,
  int value,
  Color color,
  String filterType,
) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
builder: (_) => AdminBookingListPage(
  shopId: shopId,
  filterType: filterType,
),
          ),
        );
      },
      leading: Icon(Icons.bar_chart, color: color),
      title: Text(title),
      trailing: Text(
        value.toString(),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ),
  );
}
}