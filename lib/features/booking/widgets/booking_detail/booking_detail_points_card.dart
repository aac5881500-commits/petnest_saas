// 檔案名稱：lib/features/booking/widgets/booking_detail/booking_detail_points_card.dart
// 功能說明：客戶住宿／安親訂單詳細的點數回饋。只顯示最終結果。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_points_display.dart';

class BookingDetailPointsCard extends StatelessWidget {
  const BookingDetailPointsCard({super.key, required this.booking});

  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final BookingPointsDisplay display = BookingPointsDisplay.fromBooking(
      booking,
    );
    if (!display.customerVisible) {
      return const SizedBox.shrink();
    }
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return BookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          BookingDetailSectionTitle(
            '點數回饋',
            trailing: display.issued
                ? _badge(theme, '已發放')
                : (display.pending ? _badge(theme, '待發放') : null),
          ),
          if (display.showSpend) ...<Widget>[
            const SizedBox(height: 10),
            if (display.pointsUsed > 0)
              _line(theme, '本次使用', '${display.pointsUsed} 點'),
            if (display.discountNtd > 0)
              _line(theme, '折抵', 'NT\$ ${display.discountNtd}'),
          ],
          if (display.issued) ...<Widget>[
            const SizedBox(height: 8),
            _line(theme, '本次獲得', '${display.issuedAmount} 點'),
            if (display.issuedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '發放時間 ${DaycareTimeHelper.formatDateTime(display.issuedAt!)}',
                  style: TextStyle(
                    fontSize: BookingDetailUi.captionSize,
                    color: theme.muted,
                  ),
                ),
              ),
          ] else if (display.previewPoints > 0) ...<Widget>[
            const SizedBox(height: 8),
            _line(theme, '完成訂單後預計獲得', '${display.previewPoints} 點'),
            const SizedBox(height: 4),
            Text(
              '實際回饋點數以訂單完成結算結果為準',
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: theme.muted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(ShopFrontendTheme theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: BookingDetailUi.captionSize,
                color: theme.muted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(ShopFrontendTheme theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: BookingDetailUi.captionSize,
          fontWeight: FontWeight.w700,
          color: theme.text,
        ),
      ),
    );
  }
}
