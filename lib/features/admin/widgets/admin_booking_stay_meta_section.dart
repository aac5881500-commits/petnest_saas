// 檔案名稱：lib/features/admin/widgets/admin_booking_stay_meta_section.dart
// 功能說明：住宿訂單日期／房型／房間摘要（不重算價格）。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_current_room.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_date_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/booking/widgets/booking_current_room_panel.dart';

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
          Text('入住：${adminBookingFormatDateTime(data['startDate'])}'),
          Text('退房：${adminBookingFormatDateTime(data['endDate'])}'),
          if (nights.isNotEmpty) Text('晚數：$nights'),
          const SizedBox(height: 10),
          BookingCurrentRoomPanel(
            data: data,
            audience: BookingCurrentRoomAudience.staff,
            compact: true,
          ),
        ],
      ),
    );
  }
}
