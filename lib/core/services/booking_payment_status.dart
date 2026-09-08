// 檔案名稱：lib/core/services/booking_payment_status.dart
// 功能說明：住宿／安親共用付款狀態：已付金額、訂金確認、付款期限顯示（相容舊欄位）

import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class BookingPaymentStatus {
  BookingPaymentStatus._();

  static bool isDaycare(Map<String, dynamic> data) {
    return BookingKind.resolve(data) == BookingKind.daycare;
  }

  static String daycareDepositType(Map<String, dynamic> data) {
    final String raw = (data['daycareDepositType'] ?? data['depositType'] ?? '')
        .toString()
        .trim();
    if (raw == DaycareDepositTypes.staffDecide) {
      return DaycareDepositTypes.none;
    }
    return raw;
  }

  static bool isDepositConfirmed(Map<String, dynamic> data) {
    if (data['depositPaid'] == true) {
      return true;
    }
    return (data['depositStatus'] ?? '').toString() == 'confirmed';
  }

  static int resolvePaid(Map<String, dynamic> data) {
    int paid = SafeParse.parseMoney(data['paidAmount']);
    if (!isDepositConfirmed(data)) {
      return paid;
    }
    int credit = SafeParse.parseMoney(data['depositAmount']);
    final String payAmountType = (data['payAmountType'] ?? '').toString();
    final String depositType = daycareDepositType(data);
    if (payAmountType == 'full' || depositType == DaycareDepositTypes.full) {
      final int total = _firstPositive(<dynamic>[
        data['totalPayableAmount'],
        data['totalAmount'],
        data['totalPrice'],
        data['quotedTotalPrice'],
      ]);
      if (total > credit) {
        credit = total;
      }
    }
    if (paid < credit) {
      paid = credit;
    }
    return paid;
  }

  static int resolveDepositAmount(Map<String, dynamic> data) {
    return SafeParse.parseMoney(data['depositAmount']);
  }

  static int resolveDueNow(Map<String, dynamic> data) {
    final int paid = resolvePaid(data);
    final int deposit = resolveDepositAmount(data);
    final String payAmountType = (data['payAmountType'] ?? '').toString();
    if (!isDepositConfirmed(data) && deposit > 0 && payAmountType != 'full') {
      final int due = deposit - paid;
      return due < 0 ? 0 : due;
    }
    if (isDaycare(data) && !requiresUpfrontPayment(data)) {
      return 0;
    }
    final int total = _firstPositive(<dynamic>[
      data['totalPayableAmount'],
      data['totalAmount'],
      data['totalPrice'],
      data['quotedTotalPrice'],
    ]);
    final int left = total - paid;
    return left < 0 ? 0 : left;
  }

  static int resolveRemaining({required int total, required int paid}) {
    final int left = total - paid;
    return left < 0 ? 0 : left;
  }

  /// 客戶可改付款方式／金額：未付款，或已送資料但店主尚未確認。
  static bool canChangePaymentChoice(Map<String, dynamic> data) {
    final String status = (data['status'] ?? '').toString();
    if (status == 'cancelled' ||
        status == 'completed' ||
        status == 'checked_in') {
      return false;
    }
    if (isDepositConfirmed(data)) {
      return false;
    }
    final int total = resolveTotal(data);
    final int paid = resolvePaid(data);
    if (total > 0 && paid >= total) {
      return false;
    }
    return true;
  }

  /// 安親「不收訂金／舊店員手動」不顯示付款期限；住宿維持訂金＋deadline。
  static bool showPaymentDeadline(Map<String, dynamic> data) {
    if (isDepositConfirmed(data)) {
      return false;
    }
    if (isDaycare(data)) {
      final String type = daycareDepositType(data);
      if (type == DaycareDepositTypes.none ||
          type == DaycareDepositTypes.staffDecide) {
        return false;
      }
      if (type.isEmpty && SafeParse.parseMoney(data['depositAmount']) <= 0) {
        return false;
      }
    } else if (SafeParse.parseMoney(data['depositAmount']) <= 0) {
      return false;
    }
    return data['depositExpireAt'] != null;
  }

  static bool requiresUpfrontPayment(Map<String, dynamic> data) {
    if (isDaycare(data)) {
      final String type = daycareDepositType(data);
      if (type == DaycareDepositTypes.none ||
          type == DaycareDepositTypes.staffDecide) {
        return false;
      }
      if (type == DaycareDepositTypes.fixed ||
          type == DaycareDepositTypes.percent ||
          type == DaycareDepositTypes.full) {
        return true;
      }
    }
    return SafeParse.parseMoney(data['depositAmount']) > 0;
  }

  static int resolveTotal(Map<String, dynamic> data) {
    return _firstPositive(<dynamic>[
      data['totalPayableAmount'],
      data['totalAmount'],
      data['totalPrice'],
      data['quotedTotalPrice'],
    ]);
  }

  static String depositPaidSummary(Map<String, dynamic> data) {
    final int paid = resolvePaid(data);
    final int remaining = resolveRemaining(
      total: resolveTotal(data),
      paid: paid,
    );
    return '已付訂金 NT\$$paid／尚餘 NT\$$remaining';
  }

  static String latestOrderStatusLabel(Map<String, dynamic> data) {
    final String status = (data['status'] ?? 'pending').toString();
    if (status == 'cancelled') {
      return '已取消';
    }
    if (status == 'completed') {
      return '已完成';
    }
    if (status == 'checked_in') {
      return isDaycare(data) ? '安親中' : '已入住';
    }
    if (isDaycare(data) &&
        isDepositConfirmed(data) &&
        (status == 'pending' ||
            status == 'pending_confirmation' ||
            status == 'confirmed')) {
      return '訂金已確認';
    }
    if (status == 'confirmed') {
      return '已確認';
    }
    final String depositStatus = (data['depositStatus'] ?? '').toString();
    if (depositStatus == 'pending_review') {
      return '待店家確認付款';
    }
    if (SafeParse.parseMoney(data['depositAmount']) > 0) {
      return '需支付訂金';
    }
    final String paymentMethod = (data['paymentMethod'] ?? '').toString();
    if (paymentMethod == 'transfer') {
      return '尚未轉帳';
    }
    return '待確認';
  }

  static Duration expireDuration(int hours) {
    if (hours == 0) {
      return const Duration(minutes: 1);
    }
    return Duration(hours: hours);
  }

  static bool isDeadlineOverdue(Map<String, dynamic> data, {DateTime? now}) {
    if (!showPaymentDeadline(data)) {
      return false;
    }
    final DateTime? expireAt = SafeParse.parseDate(data['depositExpireAt']);
    if (expireAt == null) {
      return false;
    }
    return (now ?? DateTime.now()).isAfter(expireAt);
  }

  static String countdownLabel(DateTime expireAt, {DateTime? now}) {
    final DateTime clock = now ?? DateTime.now();
    final Duration diff = expireAt.difference(clock);
    if (diff.isNegative || diff.inSeconds == 0) {
      return '已逾期';
    }
    final int days = diff.inDays;
    final int hours = diff.inHours % 24;
    final int minutes = diff.inMinutes % 60;
    final int seconds = diff.inSeconds % 60;
    if (days > 0) {
      return '剩餘 $days 天 $hours 小時';
    }
    if (diff.inHours > 0) {
      return '剩餘 $hours 小時 $minutes 分';
    }
    if (minutes > 0) {
      return '剩餘 $minutes 分 $seconds 秒';
    }
    return '剩餘 $seconds 秒';
  }

  static int _firstPositive(List<dynamic> values) {
    for (final dynamic value in values) {
      final int amount = SafeParse.parseMoney(value);
      if (amount > 0) {
        return amount;
      }
    }
    return 0;
  }
}
