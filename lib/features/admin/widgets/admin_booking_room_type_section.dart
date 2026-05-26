// lib/features/admin/widgets/admin_booking_room_type_section.dart
// 🛏️ 後台手動新增訂單：房型選擇區塊
// 功能：包裝前台共用房型選擇元件，提供後台手動新增訂單使用

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_room_type_section.dart';

class AdminBookingRoomTypeSection extends StatelessWidget {
  const AdminBookingRoomTypeSection({
    super.key,
    required this.shopId,
    required this.startDate,
    required this.endDate,
    required this.selectedPetIds,
    required this.selectedRoomType,
    required this.onSelectRoomType,
  });

  final String shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> selectedPetIds;
  final Map<String, dynamic>? selectedRoomType;
  final void Function(Map<String, dynamic> roomType) onSelectRoomType;

  @override
  Widget build(BuildContext context) {
    if (startDate == null || endDate == null) {
      return const SizedBox();
    }

    return BookingRoomTypeSection(
      shopId: shopId,
      startDate: startDate,
      endDate: endDate,
      selectedPetIds: selectedPetIds,
      selectedRoomType: selectedRoomType,
      onSelectRoomType: onSelectRoomType,
    );
  }
}