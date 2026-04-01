// lib/features/booking/pages/booking_detail_page.dart
// 📦 訂單詳細頁
//
// 功能：
// - 顯示訂單資料
// - 可取消訂單（pending 狀態）
// - 取消後更新 Firestore
// - 顯示提示訊息

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingDetailPage extends StatelessWidget {
  const BookingDetailPage({
    super.key,
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final start = (data['startDate'] as Timestamp).toDate();
    final end = (data['endDate'] as Timestamp).toDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('訂單詳情'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 房型
            Text('房型：${data['roomName'] ?? ''}'),
            const SizedBox(height: 12),

            /// 日期
            Text('日期：${_formatDate(start)} ～ ${_formatDate(end)}'),
            const SizedBox(height: 12),

            /// 聯絡人
            Text('聯絡人：${data['customerName'] ?? ''}'),
            const SizedBox(height: 12),

            /// 電話
            Text('電話：${data['customerPhone'] ?? ''}'),
            const SizedBox(height: 12),

            /// 服務類型
            Text('服務類型：${data['serviceType'] ?? ''}'),
            const SizedBox(height: 12),

            /// 寵物數量
            Text('寵物數量：${(data['petIds'] as List?)?.length ?? 0}'),
            const SizedBox(height: 12),

            /// 備註
            Text('備註：${data['note'] ?? ''}'),
            const SizedBox(height: 12),

            /// 價格
            Text('總價：NT\$ ${data['totalPrice'] ?? '-'}'),

            const SizedBox(height: 24),

            /// 🔥 取消訂單（只有 pending 才顯示）
            if ((data['status'] ?? 'pending') == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('確認取消'),
                        content: const Text('確定要取消此訂單嗎？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('返回'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('確定取消'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    /// 🔥 防呆：沒有 bookingId 就不做
                    final bookingId = data['bookingId'];
                    if (bookingId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('訂單資料錯誤')),
                      );
                      return;
                    }

                    /// 🔥 更新狀態
                    await FirebaseFirestore.instance
                        .collection('bookings')
                        .doc(bookingId)
                        .update({
                      'status': 'cancelled',
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('訂單已取消')),
                      );

                      Navigator.pop(context);
                    }
                  },
                  child: const Text('取消訂單'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 日期格式
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}