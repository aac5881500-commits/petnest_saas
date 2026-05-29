// lib/features/admin/widgets/admin_booking_header_card.dart
// 🏠 後台訂單詳細頁：房間主卡
// 功能：顯示訂單編號、房號、房型、晚數、入住日、退房日、下訂時間

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';

class AdminBookingHeaderCard extends StatelessWidget {
  const AdminBookingHeaderCard({
    super.key,
    required this.data,
    required this.bookingId,
  });

  final Map<String, dynamic> data;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final displayBookingCode =
        (data['bookingCode'] ?? '').toString().isNotEmpty
            ? data['bookingCode'].toString()
            : bookingId.substring(0, 8);

    final start = (data['startDate'] as Timestamp).toDate();
    final end = (data['endDate'] as Timestamp).toDate();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '訂單編號：',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Text(
                  displayBookingCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: displayBookingCode),
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已複製訂單編號'),
                      ),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.copy_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['assignStatus'] == 'unassigned'
                        ? '待分房'
                        : (data['roomName'] ?? '-'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    data['assignStatus'] == 'unassigned'
                        ? '${data['roomTypeName'] ?? ''}｜尚未選房間'
                        : (data['roomTypeName'] ?? ''),
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data['nights'] ?? 0} 晚',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '入住',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    adminBookingFormatDate(start),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const Icon(Icons.arrow_forward, color: Colors.white),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '退房',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    adminBookingFormatDate(end),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '下訂',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    adminBookingFormatDateTime(data['createdAt']),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}