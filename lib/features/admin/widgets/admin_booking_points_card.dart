// 檔案名稱：lib/features/admin/widgets/admin_booking_points_card.dart
// 功能說明：店主住宿／安親訂單詳細共用點數卡。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_points_display.dart';

class AdminBookingPointsCard extends StatelessWidget {
  const AdminBookingPointsCard({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.booking,
    this.member,
    this.lookupMember = false,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? member;

  /// 訂單頁才向會員文件確認手動會員。測試直接傳 booking／member。
  final bool lookupMember;

  @override
  Widget build(BuildContext context) {
    if (!lookupMember || member != null) {
      return _AdminBookingPointsBody(
        shopId: shopId,
        bookingId: bookingId,
        booking: booking,
        member: member,
      );
    }
    final String userId = SafeParse.parseString(booking['userId']);
    if (shopId.trim().isEmpty ||
        userId.isEmpty ||
        SafeParse.parseBool(booking['isTempAdminMember'])) {
      return _AdminBookingPointsBody(
        shopId: shopId,
        bookingId: bookingId,
        booking: booking,
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            return _AdminBookingPointsBody(
              shopId: shopId,
              bookingId: bookingId,
              booking: booking,
              member: snapshot.data?.data(),
            );
          },
    );
  }
}

class _AdminBookingPointsBody extends StatelessWidget {
  const _AdminBookingPointsBody({
    required this.shopId,
    required this.bookingId,
    required this.booking,
    this.member,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? member;

  @override
  Widget build(BuildContext context) {
    final BookingPointsDisplay display = BookingPointsDisplay.fromBooking(
      booking,
      member: member,
    );
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Container(
      key: ValueKey<String>('points-$shopId-$bookingId'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.7)),
      ),
      child: display.manualUnbound
          ? _notice(
              theme,
              '此會員尚未綁定 App 帳號，不累積會員點數',
            )
          : display.participates
          ? _lifecycle(theme, display)
          : Text(
              '本筆訂單未使用點數制度',
              style: TextStyle(fontSize: 13, color: theme.subtitleColor),
            ),
    );
  }

  Widget _lifecycle(ShopFrontendTheme theme, BookingPointsDisplay display) {
    final List<_PointMetric> metrics = <_PointMetric>[
      if (display.showSpend && display.pointsUsed > 0)
        _PointMetric('使用點數', '${display.pointsUsed} 點'),
      if (display.showSpend && display.discountNtd > 0)
        _PointMetric('折抵金額', 'NT\$ ${display.discountNtd}'),
      if (display.showSystem)
        _PointMetric('系統計算', '${display.systemPoints} 點'),
      if (display.showAdjustment)
        _PointMetric(
          '店家調整',
          '${display.finalPoints} 點',
          caption: _deltaText(display.adjustmentDelta),
        ),
      if (display.finalPoints > 0 || display.showAdjustment)
        _PointMetric('最終點數', '${display.finalPoints} 點'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '點數',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.titleColor,
                ),
              ),
            ),
            if (display.shopStatusLabel.isNotEmpty)
              _badge(display.shopStatusLabel, display.issued),
          ],
        ),
        if (metrics.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return _metricWrap(theme, metrics, constraints.maxWidth);
            },
          ),
        ],
        if (display.issued) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            '已發放 ${display.issuedAmount} 點',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.titleColor,
            ),
          ),
          if (display.issuedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '發放時間 ${DaycareTimeHelper.formatDateTime(display.issuedAt!)}',
                style: TextStyle(fontSize: 12, color: theme.subtitleColor),
              ),
            ),
        ] else if (display.pending) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            '預計 ${display.previewPoints} 點',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.titleColor,
            ),
          ),
        ],
        if (display.showAdjustment && display.adjustReason.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '調整原因 ${display.adjustReason}',
            style: TextStyle(fontSize: 12, color: theme.subtitleColor, height: 1.35),
          ),
        ],
      ],
    );
  }

  Widget _metricWrap(
    ShopFrontendTheme theme,
    List<_PointMetric> metrics,
    double maxWidth,
  ) {
    final double width = maxWidth.isFinite ? maxWidth : 320;
    final int columns = width >= 720 ? 3 : (width >= 360 ? 2 : 1);
    const double gap = 8;
    final double itemWidth = (width - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: 10,
      children: <Widget>[
        for (final _PointMetric metric in metrics)
          SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.subtitleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.titleColor,
                  ),
                ),
                if (metric.caption != null)
                  Text(
                    metric.caption!,
                    style: TextStyle(fontSize: 12, color: theme.subtitleColor),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _badge(String label, bool issued) {
    final Color color = issued
        ? ShopFrontendTheme.successColor
        : ShopFrontendTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _notice(ShopFrontendTheme theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 18, color: theme.subtitleColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.subtitleColor,
            ),
          ),
        ),
      ],
    );
  }

  static String _deltaText(int delta) {
    if (delta > 0) {
      return '+$delta';
    }
    return '$delta';
  }
}

class _PointMetric {
  const _PointMetric(this.label, this.value, {this.caption});

  final String label;
  final String value;
  final String? caption;
}
