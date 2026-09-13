// 檔案名稱：lib/features/admin/widgets/admin_booking_settlement_panel.dart
// 功能說明：結算確認後的住宿／安親結果卡；未確認不顯示操作。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/booking_settlement_function_service.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';

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
          if (method.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('補款方式：$method　狀態：${_statusLabel(topUpStatus)}'),
            ),
          if (!locked) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onReadjust ?? () => _adjust(context),
                  child: const Text('重新調整'),
                ),
                if (remain > 0)
                  OutlinedButton(
                    onPressed: () => _switchMethod(context, remain),
                    child: const Text('更換補款方式'),
                  ),
                if (remain > 0 && method == 'transfer')
                  FilledButton(
                    onPressed: () => _reviewTransfer(context),
                    child: const Text('核對轉帳'),
                  ),
                if (remain > 0 && (method == 'cash' || method.isEmpty))
                  FilledButton(
                    onPressed: () => _collect(context, remain),
                    child: const Text('確認已收到款項'),
                  ),
                if (refund > 0)
                  FilledButton(
                    onPressed: () => _refund(context, refund),
                    child: const Text('確認退款'),
                  ),
                if (remain <= 0 && refund <= 0)
                  FilledButton(
                    onPressed: () => _lockNoTopUp(context),
                    child: const Text('確認無需補款並鎖定訂單'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_review':
        return '待核對';
      case 'awaiting_proof':
        return '待上傳證明';
      case 'selected':
        return '已選擇方式';
      case 'collected':
        return '已入帳';
      case 'rejected':
        return '核對失敗';
      default:
        return status.isEmpty ? '—' : status;
    }
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
      _kv('額外收費', BookingSettlementMath.extraChargeSum(data)),
      _kv('手動調整', SafeParse.parseMoney(data['manualAdjust'])),
    ];
  }

  List<Widget> _daycareLines(Map<String, dynamic> data) {
    return <Widget>[
      Text('預約送達：${_fmt(data['scheduledStartAt'])}'),
      Text('預約接回：${_fmt(data['scheduledEndAt'])}'),
      Text('實際送達：${_fmt(data['actualStartAt'])}'),
      Text('實際接回：${_fmt(data['actualEndAt'])}'),
      _kv('預約費用', BookingSettlementMath.quotedTotal(data)),
      _kv('超時費用', SafeParse.parseMoney(data['overtimeAmount'])),
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
            child: Text(
              '店家調整說明：${SettlementAdjustDisplay.reasonOf(data)}',
            ),
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

  Future<void> _call(
    BuildContext context, {
    required String action,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    try {
      await BookingSettlementFunctionService.instance.call(
        shopId: shopId,
        bookingId: bookingId,
        action: action,
        extra: extra,
        requestId: '${action}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新結算')));
      }
    } on DaycareFunctionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<bool> _confirmLock(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認鎖定訂單'),
          content: const Text('完成後訂單將鎖定，無法再修改，請確認金額與資料正確。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認鎖定'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _adjust(BuildContext context) async {
    final TextEditingController amount = TextEditingController(
      text: '${SafeParse.parseMoney(data['manualAdjust'])}',
    );
    final TextEditingController reason = TextEditingController(
      text: (data['lastManualAdjustReason'] ?? '').toString(),
    );
    final int before = BookingSettlementMath.expectedTotal(data: data);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('重新調整最終應收'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('調整前最終應收 NT\$ $before'),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(labelText: '手動調整（正數加收、負數減收）'),
              ),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: '原因（金額變動時必填）'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await _call(
      context,
      action: 'applyAdjust',
      extra: <String, dynamic>{
        'manualAdjust': int.tryParse(amount.text.trim()) ?? 0,
        'reason': reason.text.trim(),
      },
    );
  }

  Future<void> _lockNoTopUp(BuildContext context) async {
    if (!await _confirmLock(context) || !context.mounted) {
      return;
    }
    await _call(context, action: 'confirmNoTopUpAndLock');
  }

  Future<void> _switchMethod(BuildContext context, int remain) async {
    final DocumentSnapshot<Map<String, dynamic>> shopSnap =
        await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
    if (!context.mounted) {
      return;
    }
    final ShopPaymentCatalog catalog =
        ShopPaymentMethods.settlementTopUpCatalog(
          shopData: shopSnap.data() ?? const <String, dynamic>{},
          serviceType: BookingKind.isDaycare(data)
              ? PolicyApplicableService.daycare
              : PolicyApplicableService.accommodation,
        );
    if (catalog.methods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前沒有可用補款方式，請先至店家付款設定開啟。')),
      );
      return;
    }
    String selected = catalog.methods.first.id;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('更換補款方式（待補 NT\$ $remain）'),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            items: catalog.methods
                .map(
                  (ShopPaymentMethodOption item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.title),
                  ),
                )
                .toList(),
            onChanged: (String? value) => selected = value ?? selected,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await _call(
      context,
      action: 'switchTopUpMethod',
      extra: <String, dynamic>{'method': selected},
    );
  }

  Future<void> _reviewTransfer(BuildContext context) async {
    final TextEditingController reason = TextEditingController();
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('核對轉帳補款'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('證明：${data['settlementTopUpTransferImageUrl'] ?? '尚未上傳'}'),
              Text('後五碼：${data['settlementTopUpTransferLast5'] ?? '—'}'),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: '失敗原因（拒絕時必填）'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('核對失敗'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認已入帳'),
            ),
          ],
        );
      },
    );
    if (approved == null || !context.mounted) {
      return;
    }
    if (approved == true && !await _confirmLockIfClear(context)) {
      return;
    }
    await _call(
      context,
      action: 'confirmTransferTopUp',
      extra: <String, dynamic>{
        'approved': approved,
        'reviewReason': reason.text.trim(),
      },
    );
  }

  Future<bool> _confirmLockIfClear(BuildContext context) async {
    final int remain = BookingSettlementMath.remainingDue(data: data);
    final int refund = BookingSettlementMath.refundDue(data: data);
    if (remain > 0 || refund > 0) {
      return true;
    }
    return _confirmLock(context);
  }

  Future<void> _collect(BuildContext context, int due) async {
    await _confirmMoney(
      context,
      title: '確認已收到店內款項',
      amount: due,
      action: 'confirmCollect',
    );
  }

  Future<void> _refund(BuildContext context, int due) async {
    await _confirmMoney(
      context,
      title: '確認已實際退還',
      amount: due,
      action: 'confirmRefund',
    );
  }

  Future<void> _confirmMoney(
    BuildContext context, {
    required String title,
    required int amount,
    required String action,
  }) async {
    String method = 'cash';
    final TextEditingController amountCtrl = TextEditingController(
      text: '$amount',
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('選擇方式不等於已入帳，請確認實際收退後再儲存。'),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '金額'),
              ),
              DropdownButtonFormField<String>(
                initialValue: method,
                items: action == 'confirmRefund'
                    ? const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'cash',
                          child: Text('店內退款'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'transfer',
                          child: Text('轉帳退款'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'other',
                          child: Text('其他'),
                        ),
                      ]
                    : const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'cash',
                          child: Text('店內付款'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'transfer',
                          child: Text('銀行轉帳'),
                        ),
                      ],
                onChanged: (String? value) => method = value ?? 'cash',
                decoration: const InputDecoration(labelText: '方式'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認入帳'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await _call(
      context,
      action: action,
      extra: <String, dynamic>{
        'amount': int.tryParse(amountCtrl.text.trim()) ?? 0,
        'method': method,
      },
    );
  }
}
