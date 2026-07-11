// lib/features/booking/widgets/booking_detail/booking_detail_header_section.dart
// 🏠 客戶端訂單詳細頁：房型與日期資訊區塊
// 功能：顯示房號、房型、入住退房日期、晚數、下訂時間、房間異動時間

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingDetailHeaderSection extends StatelessWidget {
  const BookingDetailHeaderSection({
    super.key,
    required this.data,
    required this.start,
    required this.end,
    required this.formatDateTime,
  });

  final Map<String, dynamic> data;
  final DateTime start;
  final DateTime end;
  final String? Function(dynamic value) formatDateTime;

  @override
  Widget build(BuildContext context) {
    final source = (data['source'] ?? '').toString();

    final sourceText = (source == 'admin' || source == 'manual')
        ? '店家代為建立'
        : 'APP 自行預約';

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
          if ((data['shopName'] ?? '').toString().isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.storefront, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (data['shopName'] ?? '').toString(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // 第一排：房號 + 房型 + 晚數
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左：房號 + 房型
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['assignStatus'] == 'unassigned'
                        ? '待分房'
                        : (data['roomName'] ?? '---'),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    data['roomTypeName'] ?? data['roomType'] ?? '未設定房型',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),

                  if (data['roomChangedAt'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '已調整房間｜${formatDateTime(data['roomChangedAt'])}',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // 右：幾晚
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 第二排：入住 / 退房 + 下訂時間
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左：入住
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('入住', style: TextStyle(color: Colors.white70)),
                  Text(
                    start.toString().substring(0, 10),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const Icon(Icons.arrow_forward, color: Colors.white),

              // 右：退房 + 下訂
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('退房', style: TextStyle(color: Colors.white70)),
                  Text(
                    end.toString().substring(0, 10),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  if (data['createdAt'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '下訂 ',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          (data['createdAt'] as Timestamp)
                              .toDate()
                              .toString()
                              .substring(0, 16),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '建立來源 ',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Text(
                        sourceText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
