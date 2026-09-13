// 檔案名稱：lib/core/services/booking_settlement_math.dart
// 功能說明：住宿／安親結算差額：最終應收、實收淨額、待補／待退。

import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class BookingSettlementMath {
  BookingSettlementMath._();

  static int extraChargeSum(Map<String, dynamic> data) {
    int sum = 0;
    final Object? raw = data['extraCharges'];
    if (raw is List) {
      for (final Object? item in raw) {
        if (item is Map) {
          sum += SafeParse.parseMoney(item['amount']);
        }
      }
    }
    if (sum <= 0) {
      sum = SafeParse.parseMoney(data['extraFee']);
    }
    return sum;
  }

  static int quotedTotal(Map<String, dynamic> data) {
    final int stored = SafeParse.parseMoney(
      data['quotedTotalPrice'] ??
          data['originalTotal'] ??
          data['estimateTotalPrice'],
    );
    if (stored > 0) {
      return stored;
    }
    final int total = SafeParse.parseMoney(
      data['totalPayableAmount'] ?? data['totalPrice'] ?? data['totalAmount'],
    );
    final int extras =
        extraChargeSum(data) + SafeParse.parseMoney(data['manualAdjust']);
    final int quoted = total - extras;
    return quoted < 0 ? 0 : quoted;
  }

  static int expectedTotal({
    required Map<String, dynamic> data,
    int? manualAdjustOverride,
  }) {
    final int quoted = quotedTotal(data);
    final int extra = extraChargeSum(data);
    final int overtime = SafeParse.parseMoney(data['overtimeAmount']);
    final int manual =
        manualAdjustOverride ?? SafeParse.parseMoney(data['manualAdjust']);
    final int expected = quoted + extra + overtime + manual;
    return expected < 0 ? 0 : expected;
  }

  static int paidAmount(Map<String, dynamic> data) {
    final int stored = SafeParse.parseMoney(data['paidAmount']);
    if (stored > 0) {
      return stored;
    }
    final int paymentPaid = SafeParse.parseMoney(data['paymentPaidAmount']);
    if (paymentPaid > 0) {
      return paymentPaid;
    }
    final bool depositConfirmed =
        data['depositPaid'] == true ||
        (data['depositStatus'] ?? '').toString() == 'confirmed';
    if (depositConfirmed) {
      return SafeParse.parseMoney(data['depositAmount']);
    }
    return 0;
  }

  static bool isSettlementConfirmed(Map<String, dynamic> data) {
    return data['settlementConfirmed'] == true ||
        data['settledAt'] != null ||
        data['finalSettlementAmount'] != null;
  }

  static bool isSettlementLocked(Map<String, dynamic> data) {
    return data['settlementLocked'] == true;
  }

  static bool canLock(Map<String, dynamic> data) {
    if (!isSettlementConfirmed(data) || isSettlementLocked(data)) {
      return false;
    }
    return remainingDue(data: data) <= 0 && refundDue(data: data) <= 0;
  }

  static int remainingDue({
    required Map<String, dynamic> data,
    int? manualAdjustOverride,
  }) {
    final int delta = balanceDelta(
      data: data,
      manualAdjustOverride: manualAdjustOverride,
    );
    return delta > 0 ? delta : 0;
  }

  static int refundDue({
    required Map<String, dynamic> data,
    int? manualAdjustOverride,
  }) {
    final int delta = balanceDelta(
      data: data,
      manualAdjustOverride: manualAdjustOverride,
    );
    return delta < 0 ? -delta : 0;
  }

  static int refundedAmount(Map<String, dynamic> data) {
    return SafeParse.parseMoney(data['refundAmount']);
  }

  static int netCollected(Map<String, dynamic> data) {
    final int net = paidAmount(data) - refundedAmount(data);
    return net < 0 ? 0 : net;
  }

  static int balanceDelta({
    required Map<String, dynamic> data,
    int? manualAdjustOverride,
  }) {
    return expectedTotal(
          data: data,
          manualAdjustOverride: manualAdjustOverride,
        ) -
        netCollected(data);
  }

  static bool isDaycare(Map<String, dynamic> data) {
    return BookingKind.isDaycare(data);
  }

  /// 安親須已結算且款項結清。住宿結算後同樣看差額；尚未結算的舊住宿仍看 status。
  static bool isOrderComplete(Map<String, dynamic> data) {
    final String status = (data['status'] ?? '').toString();
    if (status == 'cancelled' || status == 'no_show') {
      return false;
    }
    if (isDaycare(data)) {
      if (!isSettlementConfirmed(data)) {
        return false;
      }
      return remainingDue(data: data) <= 0 && refundDue(data: data) <= 0;
    }
    if (isSettlementConfirmed(data)) {
      return remainingDue(data: data) <= 0 && refundDue(data: data) <= 0;
    }
    return status == 'completed';
  }

  static bool isDaycareAwaitingClear(Map<String, dynamic> data) {
    return isDaycare(data) &&
        isSettlementConfirmed(data) &&
        !isOrderComplete(data);
  }

  static bool isStayAwaitingClear(Map<String, dynamic> data) {
    return !isDaycare(data) &&
        isSettlementConfirmed(data) &&
        !isOrderComplete(data);
  }

  static bool isAwaitingClear(Map<String, dynamic> data) {
    return isDaycareAwaitingClear(data) || isStayAwaitingClear(data);
  }
}
