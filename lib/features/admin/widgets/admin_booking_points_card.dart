// 檔案名稱：lib/features/admin/widgets/admin_booking_points_card.dart
// 功能說明：店主訂單詳情點數折抵與預計回饋摘要。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class AdminBookingPointsCard extends StatelessWidget {
  const AdminBookingPointsCard({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    if (booking['isTempAdminMember'] == true) {
      return Text(
        '此會員尚未註冊 App，無法使用或累積點數',
        style: TextStyle(fontSize: 13, color: theme.muted),
      );
    }
    final int pointsUsed = _ntd(booking['pointsUsed']);
    final int pointAmount = _ntd(
      booking['pointAmount'] ?? booking['pointsDiscountAmount'],
    );
    final int issued = _ntd(
      booking['rewardPointAmount'] ?? booking['pointsIssuedAmount'],
    );
    final int expected = _ntd(
      booking['expectedRewardPoints'] ?? booking['rewardPointsSystem'],
    );
    final String earnStatus = (booking['pointsEarnStatus'] ?? '')
        .toString()
        .trim();
    final bool issuedDone =
        issued > 0 || earnStatus == 'issued' || earnStatus == 'issued_adjusted';
    final bool used = pointAmount > 0 || pointsUsed > 0;
    return Column(
      key: ValueKey<String>('points-$shopId-$bookingId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (used)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (pointsUsed > 0)
                _chip('使用 $pointsUsed 點', ShopFrontendTheme.warningColor),
              if (pointAmount > 0)
                _chip('折抵 NT\$$pointAmount', ShopFrontendTheme.warningColor),
            ],
          )
        else
          Text('本筆未使用點數折抵', style: TextStyle(fontSize: 13, color: theme.muted)),
        if (!issuedDone && expected > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '本筆預計回饋 $expected 點',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ShopFrontendTheme.successColor,
            ),
          ),
        ],
        if (!issuedDone) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            '將於退房／訂單完成並符合條件後發放',
            style: TextStyle(fontSize: 12, color: theme.muted),
          ),
        ],
      ],
    );
  }

  static int _ntd(Object? raw) {
    if (raw is num && !raw.isFinite) {
      return 0;
    }
    final int value = SafeParse.parseMoney(raw);
    return value < 0 ? 0 : value;
  }

  static Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}
