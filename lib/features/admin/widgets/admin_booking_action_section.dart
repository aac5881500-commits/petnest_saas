// 檔案名稱：lib/features/admin/widgets/admin_booking_action_section.dart
// 功能說明：統一訂單流程為「先確認訂單 → 再分房 → 才能入住」
// 🧩 後台訂單詳細頁：操作按鈕區塊
// 並集中管理訂金確認、取消、選房、更換房間與退房完成按鈕。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';

enum AdminBookingActionChrome { full, phoneInline, phoneSticky }

class StayBookingActionFlags {
  const StayBookingActionFlags({
    required this.pendingNotice,
    required this.confirmDirect,
    required this.confirmDeposit,
    required this.confirmAfterDeposit,
    required this.assignNotice,
    required this.assignRoom,
    required this.checkIn,
    required this.changeRoom,
    required this.cancel,
    required this.checkout,
    required this.checkoutLabel,
  });

  final bool pendingNotice;
  final bool confirmDirect;
  final bool confirmDeposit;
  final bool confirmAfterDeposit;
  final bool assignNotice;
  final bool assignRoom;
  final bool checkIn;
  final bool changeRoom;
  final bool cancel;
  final bool checkout;
  final String checkoutLabel;

  bool get hasSticky =>
      confirmDirect ||
      confirmDeposit ||
      confirmAfterDeposit ||
      assignRoom ||
      checkIn ||
      changeRoom ||
      checkout;

  bool get hasInline => pendingNotice || assignNotice || cancel;
}

StayBookingActionFlags stayBookingActionFlags({
  required Map<String, dynamic> data,
  required String status,
  required num depositAmount,
  required bool depositPaid,
}) {
  final String assignStatus = data['assignStatus']?.toString() ?? 'unassigned';
  final bool isAssigned = assignStatus == 'assigned';
  final bool isPending =
      status == 'pending' ||
      status == 'pending_confirmation' ||
      status == 'unpaid';
  final bool isConfirmed = status == 'confirmed';
  final bool isCheckedIn = status == 'checked_in';
  final bool isCheckedOut = status == 'checked_out';
  final bool locked = BookingSettlementMath.isSettlementLocked(data);
  final bool canOperate = status != 'cancelled' && status != 'completed';
  return StayBookingActionFlags(
    pendingNotice: isPending,
    confirmDirect: isPending && depositAmount <= 0,
    confirmDeposit: isPending && depositAmount > 0 && depositPaid != true,
    confirmAfterDeposit: isPending && depositAmount > 0 && depositPaid == true,
    assignNotice: isConfirmed && !isAssigned,
    assignRoom: isConfirmed && !isAssigned,
    checkIn: isConfirmed && isAssigned,
    changeRoom: isAssigned && canOperate && !isCheckedOut,
    cancel: isPending || isConfirmed,
    checkout: isCheckedIn && !locked,
    checkoutLabel: '辦理退房／結算',
  );
}

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
    this.chrome = AdminBookingActionChrome.full,
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
  final AdminBookingActionChrome chrome;

  @override
  Widget build(BuildContext context) {
    final StayBookingActionFlags flags = stayBookingActionFlags(
      data: data,
      status: status,
      depositAmount: depositAmount,
      depositPaid: depositPaid,
    );
    final ButtonStyle tap = ElevatedButton.styleFrom(
      minimumSize: const Size(48, 44),
    );
    final ButtonStyle danger = OutlinedButton.styleFrom(
      minimumSize: const Size(48, 44),
      foregroundColor: Colors.red.shade700,
      side: BorderSide(color: Colors.red.shade400),
    );
    final ButtonStyle primary = ElevatedButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    );
    final ButtonStyle checkInStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    );

    final List<Widget> notices = <Widget>[
      if (flags.pendingNotice)
        _notice(color: Colors.orange, text: '請先確認訂單，確認後才能選擇房間'),
      if (flags.assignNotice)
        _notice(color: Colors.blue, text: '訂單已確認，請完成分房後再辦理入住'),
    ];
    final bool checkoutOnAside =
        chrome == AdminBookingActionChrome.full &&
        MediaQuery.sizeOf(context).width >=
            AdminBookingDetailMetrics.twoColumnMin;
    final Widget? primaryButton = _primaryButton(
      flags,
      tap: tap,
      primary: primary,
      checkInStyle: checkInStyle,
      includeCheckout: !checkoutOnAside,
    );
    final Widget changeRoomButton = OutlinedButton.icon(
      onPressed: onChangeRoom,
      style: tap,
      icon: const Icon(Icons.swap_horiz),
      label: const Text('更換房間'),
    );
    final Widget cancelButton = OutlinedButton(
      onPressed: onCancelBooking,
      style: danger,
      child: const Text('取消訂單'),
    );

    if (chrome == AdminBookingActionChrome.phoneSticky) {
      if (!flags.hasSticky) {
        return const SizedBox.shrink();
      }
      return Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool iconOnly =
                    constraints.maxWidth < 360 &&
                    flags.changeRoom &&
                    primaryButton != null;
                return Row(
                  children: <Widget>[
                    if (flags.changeRoom)
                      iconOnly
                          ? IconButton(
                              tooltip: '更換房間',
                              onPressed: onChangeRoom,
                              icon: const Icon(Icons.swap_horiz),
                            )
                          : changeRoomButton,
                    if (flags.changeRoom && primaryButton != null)
                      const SizedBox(width: 8),
                    if (primaryButton != null) Expanded(child: primaryButton),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    if (chrome == AdminBookingActionChrome.phoneInline) {
      if (!flags.hasInline) {
        return const SizedBox.shrink();
      }
      return AdminBookingDetailCard(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[...notices, if (flags.cancel) cancelButton],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ...notices,
        ?primaryButton,
        if (flags.changeRoom) changeRoomButton,
        if (flags.cancel) cancelButton,
      ],
    );
  }

  Widget? _primaryButton(
    StayBookingActionFlags flags, {
    required ButtonStyle tap,
    required ButtonStyle primary,
    required ButtonStyle checkInStyle,
    required bool includeCheckout,
  }) {
    if (flags.confirmDeposit) {
      return ElevatedButton(
        onPressed: onConfirmDeposit,
        style: primary,
        child: const Text('確認收到訂金'),
      );
    }
    if (flags.confirmDirect || flags.confirmAfterDeposit) {
      return ElevatedButton(
        onPressed: onConfirmBooking,
        style: tap,
        child: const Text('確認訂單'),
      );
    }
    if (flags.assignRoom) {
      return ElevatedButton.icon(
        onPressed: onAssignRoom,
        style: tap,
        icon: const Icon(Icons.meeting_room),
        label: const Text('選擇房間'),
      );
    }
    if (flags.checkIn) {
      return ElevatedButton(
        onPressed: onCheckIn,
        style: checkInStyle,
        child: const Text('入住'),
      );
    }
    if (flags.checkout && includeCheckout) {
      return ElevatedButton(
        onPressed: onCheckOut,
        style: primary,
        child: Text(flags.checkoutLabel),
      );
    }
    return null;
  }
}

Widget _notice({required MaterialColor color, required String text}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: color.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.shade200),
    ),
    child: Text(
      text,
      style: TextStyle(color: color.shade800, fontWeight: FontWeight.bold),
    ),
  );
}
