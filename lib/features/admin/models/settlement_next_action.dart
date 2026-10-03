// 檔案名稱：lib/features/admin/models/settlement_next_action.dart
// 功能說明：結算後「下一步」的畫面表示。只讀既有結算結果，不寫 Firestore。

import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/widgets/booking_payment_proof_button.dart';

enum SettlementNextActionKind {
  none,
  checkoutOrSettle,
  waitingCustomerPayment,
  reviewCustomerProof,
  confirmCashReceived,
  confirmTransferReceived,
  confirmRefund,
  finalizeOrder,
}

enum SettlementSecondaryAction { adjust, switchMethod, staffVerify }

class SettlementNextAction {
  const SettlementNextAction({
    required this.kind,
    this.title = '',
    this.description = '',
    this.amount,
    this.enabled = false,
    this.primaryLabel = '',
    this.done = false,
    this.secondaries = const <SettlementSecondaryAction>[],
  });

  final SettlementNextActionKind kind;
  final String title;
  final String description;
  final int? amount;
  final bool enabled;
  final String primaryLabel;
  final bool done;
  final List<SettlementSecondaryAction> secondaries;

  bool get visible => kind != SettlementNextActionKind.none || done;

  bool get hasPrimary => primaryLabel.isNotEmpty;
}

SettlementNextAction resolveSettlementNextAction(Map<String, dynamic> data) {
  final String status = (data['status'] ?? '').toString();
  final bool daycare = BookingKind.isDaycare(data);
  final bool locked = BookingSettlementMath.isSettlementLocked(data);
  final bool confirmed = BookingSettlementMath.isSettlementConfirmed(data);
  final bool cancelled = status == 'cancelled' || status == 'no_show';
  final int remain = BookingSettlementMath.remainingDue(data: data);
  final int refund = BookingSettlementMath.refundDue(data: data);

  if (cancelled) {
    if (confirmed && !locked && refund > 0) {
      return _refundAction(refund);
    }
    return const SettlementNextAction(kind: SettlementNextActionKind.none);
  }
  if (locked) {
    return const SettlementNextAction(
      kind: SettlementNextActionKind.none,
      title: '✓ 訂單已完成',
      done: true,
    );
  }
  if (!confirmed) {
    if (status == 'checked_in' || status == 'checked_out') {
      return SettlementNextAction(
        kind: SettlementNextActionKind.checkoutOrSettle,
        title: status == 'checked_out' ? '服務已結束' : '',
        description: status == 'checked_out' ? '請完成結算' : '',
        enabled: true,
        primaryLabel: daycare ? '結算安親／退房' : '辦理退房／結算',
      );
    }
    return const SettlementNextAction(kind: SettlementNextActionKind.none);
  }

  if (refund > 0) {
    return _refundAction(refund, showAdjust: true);
  }
  if (remain > 0) {
    return _collectAction(data, remain);
  }
  if (status == 'completed') {
    return const SettlementNextAction(
      kind: SettlementNextActionKind.none,
      title: '✓ 訂單已完成',
      done: true,
      secondaries: <SettlementSecondaryAction>[
        SettlementSecondaryAction.adjust,
      ],
    );
  }
  return const SettlementNextAction(
    kind: SettlementNextActionKind.finalizeOrder,
    title: '款項已結清',
    description: '待完成訂單',
    enabled: true,
    primaryLabel: '確認完成並鎖定訂單',
    secondaries: <SettlementSecondaryAction>[SettlementSecondaryAction.adjust],
  );
}

SettlementNextAction _refundAction(int refund, {bool showAdjust = false}) {
  return SettlementNextAction(
    kind: SettlementNextActionKind.confirmRefund,
    title: '待退款 NT\$$refund',
    description: '請確認已實際退還後再完成',
    amount: refund,
    enabled: true,
    primaryLabel: '確認退款 NT\$$refund',
    secondaries: showAdjust
        ? const <SettlementSecondaryAction>[SettlementSecondaryAction.adjust]
        : const <SettlementSecondaryAction>[],
  );
}

SettlementNextAction _collectAction(Map<String, dynamic> data, int remain) {
  final String method = (data['settlementTopUpMethod'] ?? '').toString();
  final String topUpStatus = (data['settlementTopUpStatus'] ?? '').toString();
  final bool proof =
      BookingPaymentProof.latestUnconfirmedBalance(data) != null ||
      topUpStatus == 'pending_review' ||
      topUpStatus == 'pending_verification';
  const List<SettlementSecondaryAction> adjustAndSwitch =
      <SettlementSecondaryAction>[
        SettlementSecondaryAction.switchMethod,
        SettlementSecondaryAction.adjust,
      ];
  if (method == 'transfer' && proof) {
    return SettlementNextAction(
      kind: SettlementNextActionKind.reviewCustomerProof,
      title: '已收到付款證明',
      description: '待核對 NT\$$remain',
      amount: remain,
      enabled: true,
      primaryLabel: '核對客戶回傳',
      secondaries: const <SettlementSecondaryAction>[
        SettlementSecondaryAction.adjust,
      ],
    );
  }
  if (method == 'cash' || method.isEmpty) {
    return SettlementNextAction(
      kind: SettlementNextActionKind.confirmCashReceived,
      title: '待補款 NT\$$remain',
      description: '請確認店內已收到款項',
      amount: remain,
      enabled: true,
      primaryLabel: '確認已收到款項 NT\$$remain',
      secondaries: adjustAndSwitch,
    );
  }
  if (method == 'transfer' &&
      (topUpStatus == 'awaiting_proof' || topUpStatus.isEmpty)) {
    return SettlementNextAction(
      kind: SettlementNextActionKind.waitingCustomerPayment,
      title: '待補款 NT\$$remain',
      description: '等待客戶上傳轉帳證明',
      amount: remain,
      enabled: false,
      primaryLabel: '等待客戶付款',
      secondaries: const <SettlementSecondaryAction>[
        SettlementSecondaryAction.switchMethod,
        SettlementSecondaryAction.adjust,
        SettlementSecondaryAction.staffVerify,
      ],
    );
  }
  if (method == 'transfer') {
    return SettlementNextAction(
      kind: SettlementNextActionKind.confirmTransferReceived,
      title: '待補款 NT\$$remain',
      description: '可於現場核對客戶轉帳是否入帳',
      amount: remain,
      enabled: true,
      primaryLabel: '現場已核對入帳 NT\$$remain',
      secondaries: adjustAndSwitch,
    );
  }
  return SettlementNextAction(
    kind: SettlementNextActionKind.waitingCustomerPayment,
    title: '待補款 NT\$$remain',
    description: '請確認補款方式與付款狀態',
    amount: remain,
    enabled: false,
    primaryLabel: '等待客戶付款',
    secondaries: adjustAndSwitch,
  );
}
