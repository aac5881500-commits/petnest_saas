// lib/features/booking/widgets/booking_detail/booking_detail_status_card.dart
// 📌 客戶端訂單詳細頁：訂單狀態提示卡
// 功能：依照訂單狀態、訂金狀態、付款方式顯示目前訂單狀態

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';

class BookingDetailStatusCard extends StatelessWidget {
  const BookingDetailStatusCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? '').toString();
    final depositStatus = (data['depositStatus'] ?? '').toString();
    final paymentMethod = (data['paymentMethod'] ?? '').toString();

    final depositAmountRaw = data['depositAmount'];
    final int depositAmount = depositAmountRaw is int
        ? depositAmountRaw
        : depositAmountRaw is double
        ? depositAmountRaw.round()
        : 0;

    final bool hasDeposit = depositAmount > 0;
    final bool isBankTransfer =
        paymentMethod == 'transfer' ||
        paymentMethod == 'bank_transfer' ||
        paymentMethod == 'bankTransfer' ||
        paymentMethod == '銀行轉帳';

    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (BookingKind.isDaycare(data)) {
      if (status == 'completed') {
        bgColor = Colors.grey.shade300;
        textColor = Colors.black87;
        text = '臨托已完成';
        icon = Icons.flag;
      } else if (status == 'cancelled') {
        bgColor = Colors.red.shade50;
        textColor = Colors.red;
        text = '訂單已取消';
        icon = Icons.cancel;
      } else if (status == 'checked_in') {
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue;
        text = '臨托中';
        icon = Icons.home;
      } else if (status == 'confirmed') {
        bgColor = Colors.green.shade50;
        textColor = Colors.green;
        text = '店家已確認';
        icon = Icons.check_circle;
      } else {
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange;
        text = '等待店家確認';
        icon = Icons.access_time;
      }
    } else if (status == 'completed') {
      bgColor = Colors.grey.shade300;
      textColor = Colors.black87;
      text = '已完成';
      icon = Icons.flag;
    } else if (status == 'cancelled') {
      bgColor = Colors.red.shade50;
      textColor = Colors.red;
      text = '已取消訂單';
      icon = Icons.cancel;
    } else if (status == 'checked_in') {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue;
      text = '入住中';
      icon = Icons.home;
    } else if (status == 'confirmed') {
      bgColor = Colors.green.shade50;
      textColor = Colors.green;
      text = '已確認訂單';
      icon = Icons.check_circle;
    } else if (depositStatus == 'pending_review') {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
      text = hasDeposit ? '已付款・待店家確認' : '已回傳轉帳・待店家確認';
      icon = Icons.receipt_long;
    } else if (hasDeposit) {
      bgColor = Colors.amber.shade100;
      textColor = Colors.amber.shade900;
      text = '需支付訂金';
      icon = Icons.account_balance_wallet;
    } else if (isBankTransfer) {
      bgColor = Colors.deepOrange.shade50;
      textColor = Colors.deepOrange.shade700;
      text = '尚未轉帳';
      icon = Icons.account_balance;
    } else {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange;
      text = BookingKind.isDaycare(data) ? '等待店家確認' : '待店家確認';
      icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
