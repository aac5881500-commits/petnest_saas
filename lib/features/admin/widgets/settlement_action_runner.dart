// 檔案名稱：lib/features/admin/widgets/settlement_action_runner.dart
// 功能說明：結算面板與下一步操作共用的既有結算 handler，不另寫付款流程。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/booking_settlement_function_service.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/settlement_adjust_display.dart';
import 'package:petnest_saas/core/services/shop_payment_methods.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/core/widgets/booking_payment_proof_button.dart';

class SettlementActionRunner {
  const SettlementActionRunner({
    required this.shopId,
    required this.bookingId,
    required this.data,
  });

  final String shopId;
  final String bookingId;
  final Map<String, dynamic> data;

  Future<void> adjust(BuildContext context) async {
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

  Future<void> lockNoTopUp(BuildContext context) async {
    if (!await _confirmLock(context) || !context.mounted) {
      return;
    }
    await _call(context, action: 'confirmNoTopUpAndLock');
  }

  Future<void> switchMethod(BuildContext context, int remain) async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前沒有可用補款方式，請先至店家付款設定開啟。')));
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

  Future<void> reviewTransfer(BuildContext context) async {
    final BookingPaymentProofRecord? proof =
        BookingPaymentProof.latestUnconfirmedBalance(data);
    if (proof == null) {
      return;
    }
    final int remain = BookingSettlementMath.remainingDue(data: data);
    final TextEditingController reason = TextEditingController();
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('核對客戶回傳'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('結算尾款'),
                Text('目前待補款：NT\$ $remain'),
                Text(
                  '照片提交時記錄金額：${proof.amount > 0 ? 'NT\$ ${proof.amount}' : '—'}',
                ),
                Text('後五碼：${proof.last5.isEmpty ? '—' : proof.last5}'),
                Text('提交時間：${_fmt(proof.submittedAt)}'),
                const SizedBox(height: 8),
                if (proof.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      proof.imageUrl,
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stack,
                          ) {
                            return Text(proof.imageUrl);
                          },
                    ),
                  )
                else
                  const Text('證明：尚未上傳'),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: '失敗原因（拒絕時必填）'),
                ),
              ],
            ),
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
    if (!context.mounted) {
      return;
    }
    await _call(
      context,
      action: 'confirmTransferTopUp',
      extra: <String, dynamic>{
        'approved': approved,
        'reviewReason': reason.text.trim(),
        'proofId': proof.proofId,
      },
    );
  }

  Future<void> staffVerifyTransfer(BuildContext context, int remain) async {
    final TextEditingController note = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('現場已核對入帳'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('待補款金額：NT\$ $remain'),
                const SizedBox(height: 8),
                const Text('客戶現場轉帳給店員看、但不願上傳照片時使用。付款方式仍記為銀行轉帳。'),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '現場核對註記（必填）',
                    hintText: '例如：客戶現場網銀轉帳，店員已確認入帳。',
                  ),
                ),
              ],
            ),
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
    if (note.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請填寫現場核對註記')));
      return;
    }
    if (!await _confirmLockIfClear(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _call(
      context,
      action: 'confirmStaffVerifiedTransfer',
      extra: <String, dynamic>{'transferVerificationNote': note.text.trim()},
    );
  }

  Future<void> collect(BuildContext context, int due) async {
    await _confirmMoney(
      context,
      title: '確認已收到店內款項',
      amount: due,
      action: 'confirmCollect',
    );
  }

  Future<void> refund(BuildContext context, int due) async {
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
    String method = action == 'confirmRefund'
        ? ((data['settlementRefundMethod'] ?? '').toString().trim().isEmpty
              ? SettlementAdjustDisplay.inStoreRefundMethod
              : (data['settlementRefundMethod'] ?? '').toString())
        : 'cash';
    final TextEditingController amountCtrl = TextEditingController(
      text: '$amount',
    );
    final TextEditingController refundNote = TextEditingController(
      text: (data['settlementRefundNote'] ?? '').toString(),
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialog) {
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
                        ? SettlementAdjustDisplay.refundMethodOptions
                              .map(
                                (Map<String, String> item) =>
                                    DropdownMenuItem<String>(
                                      value: item['id'],
                                      child: Text(item['title'] ?? ''),
                                    ),
                              )
                              .toList()
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
                    onChanged: (String? value) {
                      setDialog(() {
                        method = value ?? 'cash';
                      });
                    },
                    decoration: const InputDecoration(labelText: '方式'),
                  ),
                  if (action == 'confirmRefund' &&
                      method == SettlementAdjustDisplay.otherRefundMethod)
                    TextField(
                      controller: refundNote,
                      decoration: const InputDecoration(
                        labelText: '其他退款註記（必填）',
                      ),
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
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    if (action == 'confirmRefund' &&
        method == SettlementAdjustDisplay.otherRefundMethod &&
        refundNote.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('其他退款請填寫註記')));
      return;
    }
    await _call(
      context,
      action: action,
      extra: <String, dynamic>{
        'amount': int.tryParse(amountCtrl.text.trim()) ?? 0,
        'method': method,
        if (action == 'confirmRefund') 'refundNote': refundNote.text.trim(),
        if (action == 'confirmRefund') 'reason': refundNote.text.trim(),
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

  String _fmt(Object? raw) {
    return DaycareTimeHelper.formatDateTimeOrUnrecorded(
      SafeParse.parseDate(raw),
    );
  }
}
