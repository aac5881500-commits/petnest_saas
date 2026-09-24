// 檔案名稱：lib/core/services/settlement_adjust_display.dart
// 功能說明：安親結算手動加收／減免的顯示與正負轉換（不改計價公式）。

import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class SettlementAdjustDisplay {
  SettlementAdjustDisplay._();

  static const String inStoreRefundMethod = 'cash';
  static const String bankRefundMethod = 'transfer';
  static const String otherRefundMethod = 'other';

  static const List<Map<String, String>> refundMethodOptions =
      <Map<String, String>>[
        <String, String>{
          'id': inStoreRefundMethod,
          'title': '現場退款',
          'subtitle': '適用現金退款或店員現場轉帳退款。',
        },
        <String, String>{
          'id': bankRefundMethod,
          'title': '銀行退款',
          'subtitle': '店家後續匯款退給客戶。',
        },
        <String, String>{
          'id': otherRefundMethod,
          'title': '其他退款',
          'subtitle': '需填寫退款註記。',
        },
      ];

  static String refundMethodLabel(String method) {
    switch (method) {
      case bankRefundMethod:
        return '銀行退款';
      case otherRefundMethod:
        return '其他退款';
      case inStoreRefundMethod:
        return '現場退款';
      default:
        return method.isEmpty ? '' : method;
    }
  }

  static bool showTopUp(int remaining, int refundDue) {
    return remaining > 0;
  }

  static bool showRefund(int remaining, int refundDue) {
    return remaining <= 0 && refundDue > 0;
  }

  static int signedAmount({required bool surcharge, required int unsigned}) {
    final int value = unsigned < 0 ? 0 : unsigned;
    if (value == 0) {
      return 0;
    }
    return surcharge ? value : -value;
  }

  static String signedLabel(int amount) {
    if (amount > 0) {
      return '＋NT\$$amount';
    }
    if (amount < 0) {
      return '－NT\$${amount.abs()}';
    }
    return 'NT\$0';
  }

  static String reasonOf(Map<String, dynamic> data) {
    final String top = _reasonFrom(data);
    if (top.isNotEmpty) {
      return top;
    }
    for (final String key in <String>['settlement', 'daycareSettlement']) {
      final Object? nested = data[key];
      if (nested is Map) {
        final String value = _reasonFrom(Map<String, dynamic>.from(nested));
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  static String _reasonFrom(Map<String, dynamic> data) {
    return (data['manualAdjustmentReason'] ??
            data['lastManualAdjustReason'] ??
            data['manualAdjustReason'] ??
            '')
        .toString()
        .trim();
  }

  static bool requiresReason(int amount) => amount != 0;

  static bool isReasonMissing({required int amount, required String reason}) {
    return requiresReason(amount) && reason.trim().isEmpty;
  }

  static String shopAmountLine(int amount) {
    if (amount > 0) {
      return '手動加收：${signedLabel(amount)}';
    }
    if (amount < 0) {
      return '手動減免：${signedLabel(amount)}';
    }
    return '';
  }

  static String customerNoteOf(Map<String, dynamic> data) {
    final String reason = reasonOf(data);
    if (reason.isEmpty) {
      return '';
    }
    return '店家調整說明：$reason';
  }

  static int amountOf(Map<String, dynamic> data) {
    final dynamic raw =
        data['manualAdjust'] ?? data['manualAdjustmentAmount'] ?? 0;
    if (raw is int) {
      return raw;
    }
    return int.tryParse(raw.toString()) ?? 0;
  }

  static bool shouldShow(Map<String, dynamic> data) {
    return amountOf(data) != 0 && reasonOf(data).isNotEmpty;
  }

  static bool isLatePickupLabel(String label) {
    return label == '晚接回超時計費' ||
        label.contains('接回逾時') ||
        label == '超時加收' ||
        label.contains('晚接回逾時');
  }
}

class BookingSettlementDisplayLine {
  const BookingSettlementDisplayLine({
    required this.label,
    required this.amount,
    this.subtitle = '',
    this.isDiscount = false,
    this.isTotal = false,
    this.isReference = false,
  });

  final String label;
  final int amount;
  final String subtitle;
  final bool isDiscount;
  final bool isTotal;
  final bool isReference;
}

/// 住宿／安親客戶端最終結算明細的唯一解析來源。
class BookingFinalSettlementDisplay {
  BookingFinalSettlementDisplay._();

  static const String latePickupLabel = '晚接回超時計費';
  static const String futurePickupError = '實際接回時間不可晚於目前時間';

  static List<BookingSettlementDisplayLine> daycareLines(
    Map<String, dynamic> data,
  ) {
    final bool settled = BookingSettlementMath.isSettlementConfirmed(data);
    final List<BookingSettlementDisplayLine> out =
        <BookingSettlementDisplayLine>[];
    if (settled) {
      final int quoted = BookingSettlementMath.quotedTotal(data);
      if (quoted > 0) {
        out.add(
          BookingSettlementDisplayLine(
            label: '預約時預估總額：NT\$$quoted',
            amount: 0,
            isReference: true,
          ),
        );
      }
    }

    bool sawLatePickup = false;
    for (final BookingFeeLineItem line
        in DaycarePricingService.instance.itemLinesFromBooking(data)) {
      if (SettlementAdjustDisplay.isLatePickupLabel(line.label)) {
        if (!settled || line.amount <= 0 || sawLatePickup) {
          continue;
        }
        sawLatePickup = true;
        out.add(
          BookingSettlementDisplayLine(
            label: latePickupLabel,
            amount: line.amount,
            subtitle: _latePickupSubtitle(data, line.subtitle),
          ),
        );
        continue;
      }
      out.add(
        BookingSettlementDisplayLine(
          label: line.label,
          amount: line.kind == BookingFeeLineKind.discount
              ? line.amount.abs()
              : line.amount,
          subtitle: line.subtitle,
          isDiscount: line.kind == BookingFeeLineKind.discount,
        ),
      );
    }

    if (settled && !sawLatePickup) {
      final int overtime = SafeParse.parseMoney(data['overtimeAmount']);
      if (overtime > 0) {
        out.add(
          BookingSettlementDisplayLine(
            label: latePickupLabel,
            amount: overtime,
            subtitle: _latePickupSubtitle(data, ''),
          ),
        );
        sawLatePickup = true;
      }
    }

    for (final Map<String, dynamic> addon in SafeParse.parseMapList(
      data['addons'],
    )) {
      final String name = (addon['name'] ?? '').toString().trim();
      final int count = _money(addon['count'] ?? 1);
      final int total = _money(
        addon['total'] ?? (_money(addon['price']) * (count <= 0 ? 1 : count)),
      );
      final int amount = total > 0 ? total : _money(addon['amount']);
      if (amount == 0) {
        continue;
      }
      final bool duplicate = out.any(
        (BookingSettlementDisplayLine e) =>
            e.label == name && e.amount == amount,
      );
      if (duplicate) {
        continue;
      }
      out.add(
        BookingSettlementDisplayLine(
          label: name.isEmpty ? '加購服務' : name,
          amount: amount,
        ),
      );
    }

    if (chargeSum(
          out.where((BookingSettlementDisplayLine e) {
            return !SettlementAdjustDisplay.isLatePickupLabel(e.label);
          }).toList(),
        ) ==
        0) {
      final int quotedFallback = _estimateQuoted(data);
      if (quotedFallback > 0) {
        out.add(
          BookingSettlementDisplayLine(label: '預約費用', amount: quotedFallback),
        );
      }
    }

    _addDiscount(
      out,
      label: (data['discountCampaignName'] ?? '').toString().trim().isEmpty
          ? '優惠活動折扣'
          : (data['discountCampaignName'] ?? '').toString().trim(),
      amount: _money(data['discountAmount']),
    );
    _addDiscount(
      out,
      label: (data['couponName'] ?? '').toString().trim().isEmpty
          ? '優惠券折扣'
          : (data['couponName'] ?? '').toString().trim(),
      amount: _money(data['couponDiscountAmount']),
    );
    _addDiscount(
      out,
      label: '點數折抵',
      amount: _money(data['pointAmount'] ?? data['pointsDiscountAmount']),
    );

    if (settled) {
      final int extra = BookingSettlementMath.extraChargeSum(data);
      if (extra > 0 && !_extraChargesAreLatePickup(data)) {
        out.add(BookingSettlementDisplayLine(label: '退房追加費用', amount: extra));
      }
      final int manual = SettlementAdjustDisplay.amountOf(data);
      if (manual != 0) {
        out.add(
          BookingSettlementDisplayLine(
            label: manual > 0 ? '手動加收' : '手動減免',
            amount: manual.abs(),
            subtitle: SettlementAdjustDisplay.customerNoteOf(data),
            isDiscount: manual < 0,
          ),
        );
      }
      out.add(
        BookingSettlementDisplayLine(
          label: '最終結算應付',
          amount: BookingSettlementMath.expectedTotal(data: data),
          isTotal: true,
        ),
      );
    } else {
      out.add(
        BookingSettlementDisplayLine(
          label: '預約時預估總額',
          amount: _estimateQuoted(data),
          isTotal: true,
        ),
      );
      final int deposit = BookingPaymentStatus.isDepositConfirmed(data)
          ? BookingPaymentStatus.resolveDepositAmount(data)
          : 0;
      if (deposit > 0) {
        out.add(
          BookingSettlementDisplayLine(
            label: '已付訂金',
            amount: deposit,
            isReference: true,
          ),
        );
      }
      out.add(
        const BookingSettlementDisplayLine(
          label: '服務完成後依實際時間結算尾款',
          amount: 0,
          isReference: true,
        ),
      );
    }
    return out;
  }

  static int chargeSum(List<BookingSettlementDisplayLine> lines) {
    int sum = 0;
    for (final BookingSettlementDisplayLine line in lines) {
      if (line.isTotal || line.isReference) {
        continue;
      }
      sum += line.isDiscount ? -line.amount : line.amount;
    }
    return sum;
  }

  static void _addDiscount(
    List<BookingSettlementDisplayLine> out, {
    required String label,
    required int amount,
  }) {
    if (amount == 0) {
      return;
    }
    out.add(
      BookingSettlementDisplayLine(
        label: label,
        amount: amount.abs(),
        isDiscount: true,
      ),
    );
  }

  static bool _extraChargesAreLatePickup(Map<String, dynamic> data) {
    final Object? raw = data['extraCharges'];
    if (raw is! List) {
      return false;
    }
    if (raw.isEmpty) {
      return false;
    }
    return raw.every((dynamic item) {
      if (item is! Map) {
        return false;
      }
      final String label = (item['label'] ?? item['name'] ?? item['type'] ?? '')
          .toString();
      return SettlementAdjustDisplay.isLatePickupLabel(label);
    });
  }

  static String _latePickupSubtitle(
    Map<String, dynamic> data,
    String fallback,
  ) {
    if (fallback.trim().isNotEmpty) {
      return fallback;
    }
    final int minutes = _money(data['overtimeMinutes']);
    final int units = _money(data['overtimeUnits']);
    if (minutes > 0 && units > 0) {
      return '$minutes 分鐘／$units 單位';
    }
    if (minutes > 0) {
      return '$minutes 分鐘';
    }
    if (units > 0) {
      return '$units 單位';
    }
    return '';
  }

  static int _estimateQuoted(Map<String, dynamic> data) {
    final int quoted = BookingSettlementMath.quotedTotal(data);
    if (quoted > 0) {
      return quoted;
    }
    final Object? snap = data['daycarePricingSnapshot'];
    if (snap is Map) {
      final int fromSnap = SafeParse.parseMoney(snap['totalAmount']);
      if (fromSnap > 0) {
        return fromSnap;
      }
    }
    return SafeParse.parseMoney(data['totalAmount'] ?? data['total']);
  }

  static int _money(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum DaycareManualAdjustKind { none, surcharge, discount }

class DaycareManualAdjustInput {
  const DaycareManualAdjustInput({
    required this.kind,
    required this.unsignedAmount,
  });

  final DaycareManualAdjustKind kind;
  final int unsignedAmount;

  int get signed {
    if (kind == DaycareManualAdjustKind.none || unsignedAmount <= 0) {
      return 0;
    }
    return SettlementAdjustDisplay.signedAmount(
      surcharge: kind == DaycareManualAdjustKind.surcharge,
      unsigned: unsignedAmount,
    );
  }

  static DaycareManualAdjustInput fromSigned(int signed) {
    if (signed > 0) {
      return DaycareManualAdjustInput(
        kind: DaycareManualAdjustKind.surcharge,
        unsignedAmount: signed,
      );
    }
    if (signed < 0) {
      return DaycareManualAdjustInput(
        kind: DaycareManualAdjustKind.discount,
        unsignedAmount: signed.abs(),
      );
    }
    return const DaycareManualAdjustInput(
      kind: DaycareManualAdjustKind.none,
      unsignedAmount: 0,
    );
  }
}
