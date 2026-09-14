// 檔案名稱：lib/core/services/daycare_payment_display.dart
// 功能說明：安親訂單金額與付款狀態顯示：相容舊欄位，不以 remainingAmount==0 判定已付清

import 'package:petnest_saas/core/services/booking_payment_labels.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';

class DaycarePaymentDisplay {
  DaycarePaymentDisplay._();

  static int toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _snapshot(Map<String, dynamic> data) {
    final dynamic raw =
        data['daycarePricingSnapshot'] ?? data['pricingSnapshot'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }

  /// 依可信度取第一個大於 0 的總額；0／缺漏則繼續往下看，避免蓋掉 snapshot。
  static int resolveTotal(Map<String, dynamic> data) {
    final Map<String, dynamic> snapshot = _snapshot(data);
    final List<dynamic> candidates = <dynamic>[
      data['totalPayableAmount'],
      data['totalAmount'],
      data['totalPrice'],
      data['quotedTotalPrice'],
      data['estimateTotalPrice'],
      snapshot['totalAmount'],
      snapshot['totalPrice'],
    ];
    for (final dynamic candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final int value = toInt(candidate);
      if (value > 0) {
        return value;
      }
    }
    return 0;
  }

  static int resolvePaid(Map<String, dynamic> data) {
    return BookingPaymentStatus.resolvePaid(data);
  }

  static int resolveRemaining({required int total, required int paid}) {
    final int left = total - paid;
    return left < 0 ? 0 : left;
  }

  static bool isFullyPaid({
    required int total,
    required int paid,
    required int remaining,
  }) {
    return total > 0 && paid >= total && remaining <= 0;
  }

  static String statusLabel({
    required int total,
    required int paid,
    required int remaining,
  }) {
    if (isFullyPaid(total: total, paid: paid, remaining: remaining)) {
      return '已付清';
    }
    if (total > 0 && paid == 0) {
      return '未付款';
    }
    if (paid > 0 && paid < total) {
      return '部分付款';
    }
    return '未付款';
  }

  static String storedPaymentMethodLabel(dynamic value) {
    return BookingPaymentLabels.method(value);
  }
}
