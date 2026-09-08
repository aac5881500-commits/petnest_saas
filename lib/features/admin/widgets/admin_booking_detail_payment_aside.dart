// 檔案名稱：lib/features/admin/widgets/admin_booking_detail_payment_aside.dart
// 功能說明：店主訂單詳細右欄／手機付款摘要：金額、方式、期限倒數、完整交易

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';
import 'package:petnest_saas/core/widgets/booking_payment_deadline_banner.dart';
import 'package:petnest_saas/core/widgets/booking_payment_proof_button.dart';
import 'package:petnest_saas/features/admin/pages/admin_payment_center_page.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';

class AdminBookingDetailPaymentAside extends StatelessWidget {
  const AdminBookingDetailPaymentAside({
    super.key,
    required this.data,
    required this.bookingId,
    this.onViewTransactions,
  });

  final Map<String, dynamic> data;
  final String bookingId;
  final VoidCallback? onViewTransactions;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final int total = DaycarePaymentDisplay.resolveTotal(data);
    final int paid = BookingPaymentStatus.resolvePaid(data);
    final int remaining = BookingPaymentStatus.resolveRemaining(
      total: total,
      paid: paid,
    );
    final bool depositPaid = BookingPaymentStatus.isDepositConfirmed(data);
    final bool overdue = BookingPaymentStatus.isDeadlineOverdue(data);
    final Color accent = remaining > 0
        ? (overdue ? ShopFrontendTheme.errorColor : theme.primaryColor)
        : ShopFrontendTheme.successColor;
    return AdminBookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '付款摘要',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: theme.titleColor,
            ),
          ),
          const SizedBox(height: 12),
          _money(theme, '應付總額', total, emphasize: true),
          if (BookingPaymentStatus.resolveDepositAmount(data) > 0)
            _money(
              theme,
              BookingPaymentStatus.isDepositConfirmed(data) ? '訂金' : '本次應付訂金',
              BookingPaymentStatus.resolveDepositAmount(data),
              color: BookingPaymentStatus.isDepositConfirmed(data)
                  ? ShopFrontendTheme.successColor
                  : theme.primaryColor,
            ),
          _money(theme, '已付款', paid, color: ShopFrontendTheme.successColor),
          _money(
            theme,
            '尚需支付',
            BookingPaymentStatus.resolveDueNow(data),
            color: BookingPaymentStatus.resolveDueNow(data) > 0
                ? accent
                : theme.muted,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              _pill(
                remaining <= 0 && total > 0
                    ? '已付清'
                    : (depositPaid ? '訂金已確認' : '尚未完成付款'),
                remaining <= 0
                    ? ShopFrontendTheme.successColor
                    : ShopFrontendTheme.warningColor,
              ),
              _pill(
                DaycarePaymentDisplay.storedPaymentMethodLabel(
                  data['lastPaymentMethod'] ?? data['paymentMethod'],
                ),
                theme.muted,
              ),
            ],
          ),
          BookingPaymentDeadlineBanner(data: data),
          if ((data['paymentMethod'] ?? '').toString() ==
              'transfer') ...<Widget>[
            const SizedBox(height: 8),
            Text(
              ((data['transferLast5'] ?? '').toString().trim().isEmpty)
                  ? '尚無轉帳後五碼'
                  : '轉帳後五碼 ${(data['transferLast5'] ?? '').toString()}',
              style: TextStyle(
                color: (data['transferLast5'] ?? '').toString().trim().isEmpty
                    ? ShopFrontendTheme.warningColor
                    : theme.titleColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: BookingPaymentProofButton(data: data),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed:
                  onViewTransactions ??
                  () {
                    final String shopId = (data['shopId'] ?? '').toString();
                    if (shopId.isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('找不到店家資料')));
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AdminPaymentCenterPage(
                          shopId: shopId,
                          bookingId: bookingId,
                          bookingCode: (data['bookingCode'] ?? '').toString(),
                        ),
                      ),
                    );
                  },
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('查看完整交易'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.onPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _money(
    ShopFrontendTheme theme,
    String label,
    int amount, {
    bool emphasize = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: theme.muted, fontSize: 13),
            ),
          ),
          Text(
            'NT\$ $amount',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: emphasize ? 20 : 14,
              color: color ?? theme.titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
