// 檔案名稱：lib/features/admin/widgets/admin_booking_settlement_panel.dart
// 功能說明：結算確認後的住宿／安親結果卡；未確認不顯示操作。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/booking_payment_labels.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/settlement_action_runner.dart';

class AdminBookingSettlementPanel extends StatelessWidget {
  const AdminBookingSettlementPanel({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.data,
    this.onReadjust,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;
  final VoidCallback? onReadjust;

  @override
  Widget build(BuildContext context) {
    if (!BookingSettlementMath.isSettlementConfirmed(data)) {
      return const SizedBox.shrink();
    }
    final bool daycare = BookingKind.isDaycare(data);
    final bool locked = BookingSettlementMath.isSettlementLocked(data);
    final int expected = BookingSettlementMath.expectedTotal(data: data);
    final int paid = BookingSettlementMath.paidAmount(data);
    final int refunded = BookingSettlementMath.refundedAmount(data);
    final int net = BookingSettlementMath.netCollected(data);
    final int remain = BookingSettlementMath.remainingDue(data: data);
    final int refund = BookingSettlementMath.refundDue(data: data);
    final String method = (data['settlementTopUpMethod'] ?? '').toString();
    final String topUpStatus = (data['settlementTopUpStatus'] ?? '').toString();
    final String refundMethod =
        (data['settlementRefundMethod'] ?? data['lastRefundMethod'] ?? '')
            .toString();
    return AdminBookingDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            daycare ? '安親結算' : '住宿結算',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text('訂單已鎖定，無法再修改。'),
            )
          else
            const SizedBox(height: 8),
          if (daycare) ..._daycareLines(data) else ..._stayLines(data),
          const Divider(height: 20),
          _kv('最終應收', expected),
          _kv('成功收款總額', paid),
          _kv('已完成退款', refunded),
          _kv('實收淨額', net),
          _kv('待補款', remain),
          _kv('待退款', refund),
          if (remain > 0 && method.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '補款方式：${BookingPaymentLabels.method(method)}　付款狀態：${BookingPaymentLabels.status(topUpStatus)}',
              ),
            ),
          if (refund > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '退款方式：${SettlementAdjustDisplay.refundMethodLabel(refundMethod.isEmpty ? SettlementAdjustDisplay.inStoreRefundMethod : refundMethod)}',
              ),
            ),
          if (!locked) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed:
                      onReadjust ??
                      () => SettlementActionRunner(
                        shopId: shopId,
                        bookingId: bookingId,
                        data: data,
                      ).adjust(context),
                  child: const Text('調整結算'),
                ),
                if (remain > 0)
                  OutlinedButton(
                    onPressed: () => SettlementActionRunner(
                      shopId: shopId,
                      bookingId: bookingId,
                      data: data,
                    ).switchMethod(context, remain),
                    child: const Text('更換補款方式'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(Object? raw) {
    return DaycareTimeHelper.formatDateTimeOrUnrecorded(
      SafeParse.parseDate(raw),
    );
  }

  List<Widget> _stayLines(Map<String, dynamic> data) {
    return <Widget>[
      _kv('晚數', SafeParse.parseMoney(data['nights'])),
      _kv('房費小計', SafeParse.parseMoney(data['roomSubtotal'])),
      _kv('加購／折扣後原報價', BookingSettlementMath.quotedTotal(data)),
      if (BookingSettlementMath.extraChargeSum(data) > 0)
        _kv('額外收費', BookingSettlementMath.extraChargeSum(data)),
      _kv('手動加收／減免', SafeParse.parseMoney(data['manualAdjust'])),
    ];
  }

  List<Widget> _daycareLines(Map<String, dynamic> data) {
    return <Widget>[
      Text('預約送達：${_fmt(data['scheduledStartAt'])}'),
      Text('預約接回：${_fmt(data['scheduledEndAt'])}'),
      Text('實際送達：${_fmt(data['actualStartAt'])}'),
      Text('實際接回：${_fmt(data['actualEndAt'])}'),
      _kv('預約費用', BookingSettlementMath.quotedTotal(data)),
      _kv('晚接回超時計費', SafeParse.parseMoney(data['overtimeAmount'])),
      if (SettlementAdjustDisplay.amountOf(data) != 0) ...<Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            SettlementAdjustDisplay.shopAmountLine(
              SettlementAdjustDisplay.amountOf(data),
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (SettlementAdjustDisplay.reasonOf(data).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('店家調整說明：${SettlementAdjustDisplay.reasonOf(data)}'),
          ),
      ],
    ];
  }

  Widget _kv(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            'NT\$ $value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
