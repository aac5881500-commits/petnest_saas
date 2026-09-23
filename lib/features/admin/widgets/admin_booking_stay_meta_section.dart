// 檔案名稱：lib/features/admin/widgets/admin_booking_stay_meta_section.dart
// 功能說明：住宿訂單入住／退房日期與晚數（房型／房間只出現在上方摘要卡）。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';

class AdminBookingStayMetaSection extends StatelessWidget {
  const AdminBookingStayMetaSection({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final String nights = (data['nights'] ?? '').toString().trim();
    return AdminBookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('入住日期：${adminBookingFormatDateTime(data['startDate'])}'),
          const SizedBox(height: 6),
          Text('退房日期：${adminBookingFormatDateTime(data['endDate'])}'),
          if (nights.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text('晚數：$nights'),
          ],
        ],
      ),
    );
  }
}
