// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_camera_section.dart
// 功能說明：訂單攝影機區塊。入口跟著目前房間、店家總開關與房間訊號更新。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/booking/widgets/customer_camera_entry.dart';

class BookingDetailCameraSection extends StatelessWidget {
  const BookingDetailCameraSection({
    super.key,
    required this.data,
    required this.bookingStatus,
    this.bookingId = '',
  });

  final Map<String, dynamic> data;
  final String bookingStatus;
  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final String id = bookingId.trim().isNotEmpty
        ? bookingId.trim()
        : (data['bookingId'] ?? data['id'] ?? '').toString().trim();
    if (bookingStatus != 'checked_in' || id.isEmpty) {
      return const SizedBox.shrink();
    }
    return CustomerCameraDetailEntry(bookingId: id);
  }
}
