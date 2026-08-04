// lib/features/admin/widgets/admin_booking_action_section.dart
// 🧩 後台訂單詳細頁：操作按鈕區塊
// 功能：統一訂單流程為「先確認訂單 → 再分房 → 才能入住」，
// 並集中管理訂金確認、取消、選房、更換房間與退房完成按鈕。

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
    final String assignStatus =
        data['assignStatus']?.toString() ?? 'unassigned';

    final bool isAssigned = assignStatus == 'assigned';
    final bool isPending = status == 'pending';
    final bool isConfirmed = status == 'confirmed';
    final bool isCheckedIn = status == 'checked_in';
    final bool canOperate = status != 'cancelled' && status != 'completed';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // ===============================
        // 待確認：先完成訂金與訂單確認
        // ===============================
        if (isPending)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text(
              '請先確認訂單，確認後才能選擇房間',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // 無訂金：可直接確認訂單
        if (isPending && depositAmount <= 0)
          ElevatedButton(
            onPressed: onConfirmBooking,
            child: const Text('確認訂單'),
          ),

        // 有訂金但尚未確認收到
        if (isPending && depositAmount > 0 && depositPaid != true)
          ElevatedButton(
            onPressed: onConfirmDeposit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('確認收到訂金'),
          ),

        // 有訂金且已確認收到：才能確認訂單
        if (isPending && depositAmount > 0 && depositPaid == true)
          ElevatedButton(
            onPressed: onConfirmBooking,
            child: const Text('確認訂單'),
          ),

        // ===============================
        // 已確認：才能進行分房
        // ===============================
        if (isConfirmed && !isAssigned)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              '訂單已確認，請完成分房後再辦理入住',
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        if (isConfirmed && !isAssigned)
          ElevatedButton.icon(
            onPressed: onAssignRoom,
            icon: const Icon(Icons.meeting_room),
            label: const Text('選擇房間'),
          ),

        // ===============================
        // 已分房：才可入住或更換房間
        // ===============================
        if (isConfirmed && isAssigned)
          ElevatedButton(
            onPressed: onCheckIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('入住'),
          ),

        if (isAssigned && canOperate)
          ElevatedButton.icon(
            onPressed: onChangeRoom,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('更換房間'),
          ),

        // ===============================
        // 取消訂單
        // ===============================
        if (isPending || isConfirmed)
          ElevatedButton(
            onPressed: onCancelBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('取消訂單'),
          ),

        // ===============================
        // 入住後：退房完成
        // ===============================
        if (isCheckedIn)
          ElevatedButton(
            onPressed: onCheckOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('退房完成'),
          ),
      ],
    );
  }
}
