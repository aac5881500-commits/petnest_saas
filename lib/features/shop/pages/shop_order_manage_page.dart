// 檔案名稱 lib/features/shop/pages/shop_order_manage_page.dart
// 訂單管理頁（店家後台）

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_service.dart';

class ShopOrderManagePage extends StatelessWidget {
  const ShopOrderManagePage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單管理'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: BookingService.instance.streamShopBookings(shopId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!;

          if (bookings.isEmpty) {
            return const Center(child: Text('目前沒有訂單'));
          }

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];

              return Card(
                child: ListTile(
                  title: Text(booking['customerName'] ?? ''),
                  subtitle: Text(
                    '${_formatDate(booking['startDate'])} ~ ${_formatDate(booking['endDate'])}',
                  ),
                  trailing: Text(booking['status'] ?? ''),
                  onTap: () {
                    _showBookingDetail(context, booking);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 顯示訂單詳情
  void _showBookingDetail(
    BuildContext context, Map<String, dynamic> booking) {
  showDialog(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: Text(booking['customerName'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('電話：${booking['customerPhone']}'),
            Text('寵物：${booking['petName']}'),
            Text('狀態：${booking['status']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),

          /// 🔥 取消訂單按鈕
          TextButton(
            onPressed: () async {
              await _cancelBooking(context, booking);
            },
            child: const Text(
              '取消訂單',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _cancelBooking(
    BuildContext context, Map<String, dynamic> booking) async {
  final bookingId = booking['bookingId'];

  // 1️⃣ 改狀態
  await BookingService.instance.updateBookingStatus(
    bookingId: bookingId,
    status: 'cancelled',
  );

  // 2️⃣ 釋放房間（如果有 roomId）
  if (booking['roomId'] != null) {
    final startDate = (booking['startDate'] as dynamic).toDate();
    final endDate = (booking['endDate'] as dynamic).toDate();

    await BookingService.instance.releaseRoomCalendar(
      shopId: booking['shopId'],
      roomId: booking['roomId'],
      startDate: startDate,
      endDate: endDate,
    );
  }

  if (context.mounted) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('訂單已取消')),
    );
  }
}


  String _formatDate(dynamic value) {
    if (value == null) return '';
    final date = (value as dynamic).toDate();
    return '${date.year}-${date.month}-${date.day}';
  }
}