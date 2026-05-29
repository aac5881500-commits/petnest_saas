// lib/features/admin/widgets/admin_booking_action_section.dart
// 🧩 後台訂單詳細頁：操作按鈕區塊
// 功能：集中管理訂單確認、訂金確認、取消、入住、選房、更換房間、退房完成按鈕

import 'package:flutter/material.dart';

class AdminBookingActionSection extends StatelessWidget {
  const AdminBookingActionSection({
    super.key,
    required this.data,
    required this.status,
    required this.depositAmount,
    required this.depositPaid,
    required this.onAssignRoom,
    required this.onChangeRoom,
    required this.onConfirmBooking,
    required this.onConfirmDeposit,
    required this.onCancelBooking,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final Map<String, dynamic> data;
  final String status;
  final num depositAmount;
  final bool depositPaid;

  final Future<void> Function() onAssignRoom;
  final Future<void> Function() onChangeRoom;
  final Future<void> Function() onConfirmBooking;
  final Future<void> Function() onConfirmDeposit;
  final Future<void> Function() onCancelBooking;
  final Future<void> Function() onCheckIn;
  final Future<void> Function() onCheckOut;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        if (data['assignStatus'] == 'unassigned' &&
            status != 'cancelled' &&
            status != 'completed')
          ElevatedButton.icon(
            onPressed: onAssignRoom,
            icon: const Icon(Icons.meeting_room),
            label: const Text('選擇房間'),
          ),

        if (status == 'pending' && data['assignStatus'] != 'assigned')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              '請先完成分房，才能確認訂單',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        if (status == 'pending' &&
            depositAmount <= 0 &&
            data['assignStatus'] == 'assigned')
          ElevatedButton(
            onPressed: onConfirmBooking,
            child: const Text('確認'),
          ),

        if (status == 'pending' && depositAmount > 0 && depositPaid != true)
          ElevatedButton(
            onPressed: onConfirmDeposit,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('確認收到訂金'),
          ),

        if (status == 'pending' &&
            depositAmount > 0 &&
            depositPaid &&
            data['assignStatus'] == 'assigned')
          ElevatedButton(
            onPressed: onConfirmBooking,
            child: const Text('確認訂單'),
          ),

        if (status == 'pending' || status == 'confirmed')
          ElevatedButton(
            onPressed: onCancelBooking,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('取消訂單'),
          ),

        if (status == 'confirmed')
          ElevatedButton(
            onPressed: onCheckIn,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('入住'),
          ),

        if (data['assignStatus'] == 'assigned' &&
            status != 'cancelled' &&
            status != 'completed')
          ElevatedButton.icon(
            onPressed: onChangeRoom,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('更換房間'),
          ),

        if (status == 'checked_in')
          ElevatedButton(
            onPressed: onCheckOut,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('退房完成'),
          ),
      ],
    );
  }
}