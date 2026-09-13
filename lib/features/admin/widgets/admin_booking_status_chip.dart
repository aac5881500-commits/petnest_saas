// 檔案名稱：lib/features/admin/widgets/admin_booking_status_chip.dart
// 功能說明：依照訂單 status／付款狀態顯示顏色標籤

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';

class AdminBookingStatusChip extends StatelessWidget {
  const AdminBookingStatusChip({
    super.key,
    required this.status,
    this.daycare = false,
    this.paymentPending = false,
    this.depositConfirmed = false,
    this.data,
  });

  final String status;
  final bool daycare;
  final bool paymentPending;
  final bool depositConfirmed;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final _ChipStyle style = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.text,
        style: TextStyle(
          color: style.color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  _ChipStyle _resolve() {
    if (status == 'cancelled') {
      return const _ChipStyle('已取消', ShopFrontendTheme.errorColor);
    }
    if (daycare && data != null) {
      final String text = DaycareStatusLabels.primary(data!);
      Color color = ShopFrontendTheme.warningColor;
      if (text == '已完成' || text == '訂金已確認' || text == '已確認') {
        color = ShopFrontendTheme.successColor;
      } else if (text == '待補款' || text == '待退款') {
        color = ShopFrontendTheme.errorColor;
      } else if (status == 'checked_in') {
        color = Colors.blue.shade700;
      } else if (status == 'confirmed') {
        color = ShopFrontendTheme.successColor;
      }
      return _ChipStyle(text, color);
    }
    if (status == 'checked_out') {
      return _ChipStyle(
        DaycareStatusLabels.primary(
          data ?? <String, dynamic>{'status': status},
        ),
        ShopFrontendTheme.errorColor,
      );
    }
    if (status == 'completed') {
      return const _ChipStyle('已完成', ShopFrontendTheme.successColor);
    }
    if (status == 'checked_in') {
      return _ChipStyle(daycare ? '安親中' : '入住中', Colors.blue.shade700);
    }
    if (paymentPending) {
      return const _ChipStyle('待付款', ShopFrontendTheme.errorColor);
    }
    if (daycare &&
        depositConfirmed &&
        (status == 'pending' ||
            status == 'pending_confirmation' ||
            status == 'confirmed')) {
      return const _ChipStyle('訂金已確認', ShopFrontendTheme.successColor);
    }
    if (daycare) {
      return _ChipStyle(
        DaycareStatusLabels.primary(<String, dynamic>{'status': status}),
        status == 'confirmed'
            ? ShopFrontendTheme.successColor
            : ShopFrontendTheme.warningColor,
      );
    }
    switch (status) {
      case 'confirmed':
        return const _ChipStyle('已確認', ShopFrontendTheme.successColor);
      default:
        return const _ChipStyle('待確認', ShopFrontendTheme.warningColor);
    }
  }
}

class _ChipStyle {
  const _ChipStyle(this.text, this.color);
  final String text;
  final Color color;
}

String adminBookingStatusText(dynamic value) {
  switch (value) {
    case 'pending':
      return '待確認';
    case 'confirmed':
      return '已確認';
    case 'checked_in':
      return '入住中';
    case 'checked_out':
      return '已退房／待結清';
    case 'completed':
      return '已完成';
    case 'cancelled':
      return '已取消';
    default:
      return value?.toString() ?? '-';
  }
}
