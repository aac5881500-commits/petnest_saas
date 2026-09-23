// 檔案名稱：lib/core/services/daycare_pricing_service.dart
// 功能說明：臨托計價：前台、手動訂單與測試共用同一套公式。
// 金額一律四捨五入為整數新台幣。

import 'package:petnest_saas/core/models/booking_fee_line_item.dart';
import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

class DaycareQuote {
  const DaycareQuote({
    required this.durationMinutes,
    required this.baseAmount,
    required this.extraPetAmount,
    required this.roomTypeExtra,
    required this.addonAmount,
    required this.surchargeAmount,
    required this.discountAmount,
    required this.couponAmount,
    required this.pointAmount,
    required this.overtimeAmount,
    required this.manualAdjust,
    required this.totalAmount,
    required this.depositAmount,
    this.extraTimeAmount = 0,
    this.extraMinutes = 0,
    this.extraUnits = 0,
    this.includedMinutes = 0,
    this.extraBillingMinutes = 60,
    this.extraPetCount = 0,
    this.timeCharge = 0,
    this.maxBaseCharge = 0,
    this.uncappedTimeCharge = 0,
  });

  final int durationMinutes;
  final int baseAmount;
  final int extraPetAmount;
  final int roomTypeExtra;
  final int addonAmount;
  final int surchargeAmount;
  final int discountAmount;
  final int couponAmount;
  final int pointAmount;
  final int overtimeAmount;
  final int manualAdjust;
  final int totalAmount;
  final int depositAmount;
  final int extraTimeAmount;
  final int extraMinutes;
  final int extraUnits;
  final int includedMinutes;
  final int extraBillingMinutes;
  final int extraPetCount;
  final int timeCharge;
  final int maxBaseCharge;
  final int uncappedTimeCharge;

  int get timeChargeCapDiscount {
    final int discount = uncappedTimeCharge - timeCharge;
    return discount > 0 ? discount : 0;
  }

  Map<String, dynamic> toPriceSnapshot() {
    return <String, dynamic>{
      'durationMinutes': durationMinutes,
      'baseAmount': baseAmount,
      'timeCharge': timeCharge,
      'uncappedTimeCharge': uncappedTimeCharge,
      'timeChargeCapDiscount': timeChargeCapDiscount,
      'extraTimeAmount': extraTimeAmount,
      'extraMinutes': extraMinutes,
      'extraUnits': extraUnits,
      'includedMinutes': includedMinutes,
      'extraBillingMinutes': extraBillingMinutes,
      'extraPetAmount': extraPetAmount,
      'extraPetCount': extraPetCount,
      'addonAmount': addonAmount,
      'discountAmount': discountAmount,
      'couponAmount': couponAmount,
      'pointAmount': pointAmount,
      'surchargeAmount': surchargeAmount,
      'overtimeAmount': overtimeAmount,
      'totalAmount': totalAmount,
      'depositAmount': depositAmount,
      'maxBaseCharge': maxBaseCharge,
    };
  }

  int get remainingAmount =>
      (totalAmount - depositAmount).clamp(0, totalAmount);
}

class DaycareRoomQuote {
  const DaycareRoomQuote({
    required this.durationMinutes,
    required this.baseAmount,
    required this.extraPetAmount,
    required this.extraTimeAmount,
    required this.uncappedRoomAmount,
    required this.capAmount,
    required this.cappedRoomAmount,
    required this.roundingMode,
    required this.capMode,
    this.extraMinutes = 0,
    this.extraUnits = 0,
    this.includedMinutes = 0,
    this.extraBillingMinutes = 60,
    this.extraPetCount = 0,
    this.timeCharge = 0,
    this.maxBaseCharge = 0,
    this.uncappedTimeCharge = 0,
  });

  final int durationMinutes;
  final int baseAmount;
  final int extraPetAmount;
  final int extraTimeAmount;
  final int uncappedRoomAmount;
  final int capAmount;
  final int cappedRoomAmount;
  final String roundingMode;
  final String capMode;
  final int extraMinutes;
  final int extraUnits;
  final int includedMinutes;
  final int extraBillingMinutes;
  final int extraPetCount;
  final int timeCharge;
  final int maxBaseCharge;
  final int uncappedTimeCharge;
}

class DaycareTimeCharge {
  const DaycareTimeCharge({
    required this.durationMinutes,
    required this.includedMinutes,
    required this.extraMinutes,
    required this.extraUnits,
    required this.extraBillingMinutes,
    required this.uncappedTimeCharge,
    required this.timeCharge,
    required this.extraPetCount,
    required this.extraPetCharge,
    required this.maxBaseCharge,
  });

  final int durationMinutes;
  final int includedMinutes;
  final int extraMinutes;
  final int extraUnits;
  final int extraBillingMinutes;
  final int uncappedTimeCharge;
  final int timeCharge;
  final int extraPetCount;
  final int extraPetCharge;
  final int maxBaseCharge;

  int get subtotal => timeCharge + extraPetCharge;
}

class DaycareSettlement {
  const DaycareSettlement({
    required this.quotedTotal,
    required this.overtimeMinutes,
    required this.overtimeAmount,
    required this.capAmount,
    required this.finalTotal,
    required this.paidAmount,
    required this.waivedOvertime,
    required this.roundingLabel,
  });

  final int quotedTotal;
  final int overtimeMinutes;
  final int overtimeAmount;
  final int capAmount;
  final int finalTotal;
  final int paidAmount;
  final bool waivedOvertime;
  final String roundingLabel;

  int get remainingAmount => (finalTotal - paidAmount).clamp(0, finalTotal);

  String get paymentStatus {
    if (remainingAmount <= 0 && paidAmount > 0) {
      return 'paid';
    }
    if (paidAmount > 0 && remainingAmount > 0) {
      return 'partial';
    }
    if (remainingAmount > 0 && quotedTotal >= 0) {
      return 'unpaid';
    }
    return 'unpaid';
  }
}

class DaycareLatePickupBreakdown {
  const DaycareLatePickupBreakdown({
    required this.extraMinutes,
    required this.graceMinutes,
    required this.billableMinutes,
    required this.unitMinutes,
    required this.unitPrice,
    required this.units,
    required this.amount,
    required this.enabled,
  });

  final int extraMinutes;
  final int graceMinutes;
  final int billableMinutes;
  final int unitMinutes;
  final int unitPrice;
  final int units;
  final int amount;
  final bool enabled;

  String get formula {
    if (amount <= 0 || units <= 0) {
      return '未加收';
    }
    if (unitMinutes == 30) {
      return '$units 個 30 分鐘 × NT\$$unitPrice';
    }
    return '$units 小時 × NT\$$unitPrice';
  }
}

class DaycareHourlyDisplayInfo {
  const DaycareHourlyDisplayInfo({
    required this.billingModeLabel,
    required this.ruleText,
    required this.startRuleText,
    required this.extraRuleText,
    required this.reservationText,
    required this.thisChargeText,
    required this.capText,
    required this.itemLines,
  });

  final String billingModeLabel;
  final String ruleText;
  final String startRuleText;
  final String extraRuleText;
  final String reservationText;
  final String thisChargeText;
  final String capText;
  final List<BookingFeeLineItem> itemLines;
}

class DaycarePricingService {
  DaycarePricingService._();

  static final DaycarePricingService instance = DaycarePricingService._();

  static int roundMoney(num value) => value.round();

  static int readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static String minutesLabel(int minutes) {
    if (minutes <= 0) {
      return '0 分鐘';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60} 小時';
    }
    if (minutes > 60) {
      return '${minutes ~/ 60} 小時 ${minutes % 60} 分鐘';
    }
    return '$minutes 分鐘';
  }

  static String hourlyBillingRuleText({
    required int includedMinutes,
    required int basePrice,
    required int extraBillingMinutes,
    required int extraBillingPrice,
  }) {
    final String included = minutesLabel(
      includedMinutes < 1 ? 0 : includedMinutes,
    );
    if (extraBillingMinutes == 30) {
      return '起步 $included NT\$$basePrice，超過後每 30 分鐘 NT\$$extraBillingPrice；不足 30 分鐘以 30 分鐘計。';
    }
    return '起步 $included NT\$$basePrice，超過後每小時 NT\$$extraBillingPrice；不足 1 小時以 1 小時計。';
  }

  static String extraUnitRateText({
    required int extraBillingMinutes,
    required int extraBillingPrice,
  }) {
    if (extraBillingMinutes == 30) {
      return '每 30 分鐘 NT\$$extraBillingPrice';
    }
    return '每小時 NT\$$extraBillingPrice';
  }

  static String extraOvertimeLineLabel({
    required int extraMinutes,
    required int extraUnits,
    required int extraBillingMinutes,
    required int unitPrice,
  }) {
    final int billedMinutes = extraMinutes > 0
        ? extraMinutes
        : extraUnits * (extraBillingMinutes == 30 ? 30 : 60);
    final String over = minutesLabel(billedMinutes);
    if (extraBillingMinutes == 30) {
      return '超過起步 $over（$extraUnits 個 30 分鐘 × NT\$$unitPrice）';
    }
    return '超過起步 $over（$extraUnits 小時 × NT\$$unitPrice）';
  }

  DaycareTimeCharge quoteTimeCharge({
    required int includedMinutes,
    required int basePrice,
    required int extraBillingMinutes,
    required int extraBillingPrice,
    required int extraPetPrice,
    required int maxBaseCharge,
    required int durationMinutes,
    required int petCount,
  }) {
    final int safeMinutes = durationMinutes < 0 ? 0 : durationMinutes;
    final int included = includedMinutes < 1 ? 1 : includedMinutes;
    final int unit = extraBillingMinutes == 30 ? 30 : 60;
    final int extraMinutes = (safeMinutes - included).clamp(0, 24 * 60);
    final int units = extraMinutes > 0 ? (extraMinutes / unit).ceil() : 0;
    final int uncapped = basePrice + units * extraBillingPrice;
    final int timeCharge = maxBaseCharge > 0
        ? (uncapped < maxBaseCharge ? uncapped : maxBaseCharge)
        : uncapped;
    final int extraPetCount = (petCount - 1).clamp(0, 99);
    final int extraPetCharge = extraPetCount * extraPetPrice;
    return DaycareTimeCharge(
      durationMinutes: safeMinutes,
      includedMinutes: included,
      extraMinutes: extraMinutes,
      extraUnits: units,
      extraBillingMinutes: unit,
      uncappedTimeCharge: uncapped,
      timeCharge: timeCharge,
      extraPetCount: extraPetCount,
      extraPetCharge: extraPetCharge,
      maxBaseCharge: maxBaseCharge < 0 ? 0 : maxBaseCharge,
    );
  }

  Map<String, dynamic> timeChargeSnapshot(DaycareTimeCharge charge) {
    return <String, dynamic>{
      'includedMinutes': charge.includedMinutes,
      'extraMinutes': charge.extraMinutes,
      'extraUnits': charge.extraUnits,
      'extraBillingMinutes': charge.extraBillingMinutes,
      'uncappedTimeCharge': charge.uncappedTimeCharge,
      'timeCharge': charge.timeCharge,
      'extraPetCount': charge.extraPetCount,
      'extraPetCharge': charge.extraPetCharge,
      'maxBaseCharge': charge.maxBaseCharge,
      'durationMinutes': charge.durationMinutes,
    };
  }

  List<BookingFeeLineItem> timeChargeItemLines({
    required int baseAmount,
    required int includedMinutes,
    required int extraMinutes,
    required int extraUnits,
    required int extraBillingMinutes,
    required int extraBillingPrice,
    required int extraTimeAmount,
    required int extraPetCount,
    required int extraPetAmount,
    int extraPetUnitPrice = 0,
    int maxBaseCharge = 0,
    int timeCharge = 0,
    int uncappedTimeCharge = 0,
    int surchargeAmount = 0,
    int timeAddonAmount = 0,
    int overtimeAmount = 0,
    int overtimeMinutes = 0,
    int overtimeUnits = 0,
  }) {
    final List<BookingFeeLineItem> lines = <BookingFeeLineItem>[];
    final int unit = extraBillingMinutes == 30 ? 30 : 60;
    if (baseAmount > 0) {
      final String includedLabel = includedMinutes > 0
          ? minutesLabel(includedMinutes)
          : '';
      lines.add(
        BookingFeeLineItem(
          label: includedLabel.isEmpty ? '起步費' : '起步費（含 $includedLabel）',
          amount: baseAmount,
        ),
      );
    }
    final int extraTime = extraTimeAmount > 0
        ? extraTimeAmount
        : (extraUnits > 0 && uncappedTimeCharge > baseAmount
              ? (uncappedTimeCharge - baseAmount).clamp(0, 1 << 30)
              : 0);
    if (extraTime > 0) {
      final int units = extraUnits > 0
          ? extraUnits
          : (extraMinutes > 0 ? (extraMinutes / unit).ceil() : 0);
      final int unitPrice = units > 0
          ? extraTime ~/ units
          : (extraBillingPrice > 0 ? extraBillingPrice : extraTime);
      final int shownUnits = units > 0 ? units : 1;
      lines.add(
        BookingFeeLineItem(
          label: extraOvertimeLineLabel(
            extraMinutes: extraMinutes,
            extraUnits: shownUnits,
            extraBillingMinutes: unit,
            unitPrice: unitPrice,
          ),
          amount: extraTime,
          subtitle: extraUnitRateText(
            extraBillingMinutes: unit,
            extraBillingPrice: unitPrice,
          ),
        ),
      );
    } else if (baseAmount <= 0 && timeCharge > 0) {
      lines.add(BookingFeeLineItem(label: '安親時間費用', amount: timeCharge));
    }

    final int uncapped = uncappedTimeCharge > 0
        ? uncappedTimeCharge
        : (baseAmount + extraTime);
    final int charged = timeCharge > 0 ? timeCharge : uncapped;
    final int capDiscount = maxBaseCharge > 0 && uncapped > charged
        ? uncapped - charged
        : 0;
    if (capDiscount > 0 && maxBaseCharge > 0) {
      lines.add(
        BookingFeeLineItem(
          label: '已套用當次最高費用 NT\$$maxBaseCharge',
          amount: -capDiscount,
          kind: BookingFeeLineKind.discount,
        ),
      );
    }

    if (extraPetCount > 0 && extraPetAmount > 0) {
      final int unitPrice = extraPetUnitPrice > 0
          ? extraPetUnitPrice
          : extraPetAmount ~/ extraPetCount;
      lines.add(
        BookingFeeLineItem(
          label: unitPrice > 0
              ? '多寵費（增加 $extraPetCount 隻 × NT\$$unitPrice）'
              : '多寵費（增加 $extraPetCount 隻）',
          amount: extraPetAmount,
        ),
      );
    } else if (extraPetAmount > 0) {
      lines.add(BookingFeeLineItem(label: '多寵費', amount: extraPetAmount));
    }
    if (surchargeAmount > 0) {
      lines.add(BookingFeeLineItem(label: '特殊日期加價', amount: surchargeAmount));
    }
    if (timeAddonAmount > 0) {
      lines.add(BookingFeeLineItem(label: '時間加購', amount: timeAddonAmount));
    }
    if (overtimeAmount > 0) {
      lines.add(
        BookingFeeLineItem(
          label: '晚接回超時計費',
          amount: overtimeAmount,
          subtitle: overtimeMinutes > 0 && overtimeUnits > 0
              ? '$overtimeMinutes 分鐘／$overtimeUnits 單位'
              : (overtimeMinutes > 0
                    ? '$overtimeMinutes 分鐘'
                    : (overtimeUnits > 0 ? '$overtimeUnits 單位' : '')),
        ),
      );
    }
    return lines;
  }

  List<BookingFeeLineItem> customerFeeLines({
    required DaycareQuote quote,
    required String primaryLabel,
    List<BookingFeeLineItem> addonLines = const <BookingFeeLineItem>[],
    String depositType = DaycareDepositTypes.none,
    bool isRoomBased = false,
    bool includePayable = true,
  }) {
    final List<BookingFeeLineItem> lines = timeChargeItemLines(
      baseAmount: quote.baseAmount,
      includedMinutes: quote.includedMinutes,
      extraMinutes: quote.extraMinutes,
      extraUnits: quote.extraUnits,
      extraBillingMinutes: quote.extraBillingMinutes,
      extraBillingPrice: quote.extraUnits > 0 && quote.extraTimeAmount > 0
          ? quote.extraTimeAmount ~/ quote.extraUnits
          : 0,
      extraTimeAmount: quote.extraTimeAmount,
      extraPetCount: quote.extraPetCount,
      extraPetAmount: quote.extraPetAmount,
      maxBaseCharge: quote.maxBaseCharge,
      timeCharge: quote.timeCharge,
      uncappedTimeCharge: quote.uncappedTimeCharge,
      surchargeAmount: quote.surchargeAmount,
      overtimeAmount: quote.overtimeAmount,
    );
    if (addonLines.isNotEmpty) {
      lines.addAll(addonLines);
    }
    if (quote.couponAmount > 0) {
      lines.add(
        BookingFeeLineItem(
          label: '優惠券折抵',
          amount: -quote.couponAmount,
          kind: BookingFeeLineKind.discount,
        ),
      );
    }
    if (quote.discountAmount > 0) {
      lines.add(
        BookingFeeLineItem(
          label: '優惠折抵',
          amount: -quote.discountAmount,
          kind: BookingFeeLineKind.discount,
        ),
      );
    }
    if (quote.pointAmount > 0) {
      lines.add(
        BookingFeeLineItem(
          label: '點數折抵',
          amount: -quote.pointAmount,
          kind: BookingFeeLineKind.discount,
        ),
      );
    }
    lines.add(
      BookingFeeLineItem(
        label: '預估總額',
        amount: quote.totalAmount,
        kind: BookingFeeLineKind.total,
      ),
    );
    if (includePayable) {
      lines.add(
        BookingFeeLineItem(
          label: payableLabel(depositType),
          amount: payableAmount(quote: quote, depositType: depositType),
          kind: BookingFeeLineKind.payable,
        ),
      );
    }
    return lines;
  }

  List<BookingFeeLineItem> itemLinesFromBooking(Map<String, dynamic> booking) {
    final Map<String, dynamic> snap = readMap(
      booking['daycarePricingSnapshot'],
    );
    final Map<String, dynamic> timeSnap = readMap(
      booking['timeChargeSnapshot'],
    );
    final Map<String, dynamic> plan = readMap(
      booking['daycarePlanPriceSnapshot'] ?? booking['daycarePlanSnapshot'],
    );
    final Map<String, dynamic> room = readMap(
      booking['requestedRoomTypePriceSnapshot'],
    );
    final Map<String, dynamic> rateSource = plan;

    int extraBillingMinutes = readInt(
      snap['extraBillingMinutes'] ?? timeSnap['extraBillingMinutes'],
    );
    if (extraBillingMinutes != 30 && extraBillingMinutes != 60) {
      extraBillingMinutes = readInt(
        rateSource['extraBillingMinutes'] ?? room['extraBillingMinutes'],
      );
    }
    if (extraBillingMinutes != 30) {
      extraBillingMinutes = 60;
    }

    int includedMinutes = readInt(
      snap['includedMinutes'] ?? timeSnap['includedMinutes'],
    );
    if (includedMinutes <= 0) {
      includedMinutes = readInt(
        rateSource['includedMinutes'] ?? room['includedMinutes'],
      );
    }

    int extraTimeAmount = readInt(snap['extraTimeAmount']);
    if (extraTimeAmount <= 0) {
      extraTimeAmount = readInt(snap['roomTypeExtra']);
    }

    int extraUnits = readInt(snap['extraUnits'] ?? timeSnap['extraUnits']);
    int extraMinutes = readInt(
      snap['extraMinutes'] ?? timeSnap['extraMinutes'],
    );
    if (extraMinutes <= 0 && extraUnits > 0) {
      extraMinutes = extraUnits * extraBillingMinutes;
    }

    int extraBillingPrice = readInt(
      rateSource['extraBillingPrice'] ?? room['extraBillingPrice'],
    );
    if (extraBillingPrice <= 0 && extraUnits > 0 && extraTimeAmount > 0) {
      extraBillingPrice = extraTimeAmount ~/ extraUnits;
    }

    int baseAmount = readInt(snap['baseAmount']);
    if (baseAmount <= 0) {
      baseAmount = readInt(rateSource['basePrice'] ?? room['basePrice']);
    }
    final int timeCharge = readInt(
      snap['timeCharge'] ?? timeSnap['timeCharge'],
    );
    final int uncappedTimeCharge = readInt(
      snap['uncappedTimeCharge'] ?? timeSnap['uncappedTimeCharge'],
    );
    final int maxBaseCharge = readInt(
      snap['maxBaseCharge'] ??
          timeSnap['maxBaseCharge'] ??
          rateSource['maxBaseCharge'] ??
          room['maxBaseCharge'],
    );
    if (baseAmount <= 0 &&
        extraTimeAmount > 0 &&
        timeCharge > extraTimeAmount) {
      final bool capped =
          maxBaseCharge > 0 &&
          uncappedTimeCharge > 0 &&
          timeCharge < uncappedTimeCharge;
      if (!capped) {
        baseAmount = timeCharge - extraTimeAmount;
      }
    }
    if (baseAmount <= 0 && extraTimeAmount <= 0 && timeCharge > 0) {
      baseAmount = timeCharge;
    }

    final int extraPetAmount = readInt(
      snap['extraPetAmount'] ?? timeSnap['extraPetCharge'],
    );
    int extraPetCount = readInt(
      snap['extraPetCount'] ?? timeSnap['extraPetCount'],
    );
    if (extraPetCount <= 0 && extraPetAmount > 0) {
      extraPetCount = 1;
    }
    int extraPetUnitPrice = readInt(
      rateSource['extraPetPrice'] ?? room['extraPetPrice'],
    );
    if (extraPetUnitPrice <= 0 && extraPetCount > 0 && extraPetAmount > 0) {
      extraPetUnitPrice = extraPetAmount ~/ extraPetCount;
    }

    final int surchargeAmount = readInt(
      snap['surchargeAmount'] ?? booking['specialDateSurchargeAmount'],
    );
    final int timeAddonAmount = readInt(
      snap['timeAddonAmount'] ?? booking['timeAddonAmount'],
    );
    final int overtimeAmount = readInt(
      booking['overtimeAmount'] ?? snap['overtimeAmount'],
    );
    final int overtimeMinutes = readInt(booking['overtimeMinutes']);
    final int overtimeUnits = readInt(booking['overtimeUnits']);

    return timeChargeItemLines(
      baseAmount: baseAmount,
      includedMinutes: includedMinutes,
      extraMinutes: extraMinutes,
      extraUnits: extraUnits,
      extraBillingMinutes: extraBillingMinutes,
      extraBillingPrice: extraBillingPrice,
      extraTimeAmount: extraTimeAmount,
      extraPetCount: extraPetCount,
      extraPetAmount: extraPetAmount,
      extraPetUnitPrice: extraPetUnitPrice,
      maxBaseCharge: maxBaseCharge,
      timeCharge: timeCharge,
      uncappedTimeCharge: uncappedTimeCharge,
      surchargeAmount: surchargeAmount,
      timeAddonAmount: timeAddonAmount,
      overtimeAmount: overtimeAmount,
      overtimeMinutes: overtimeMinutes,
      overtimeUnits: overtimeUnits,
    );
  }

  String hourlyRuleTextFromQuote(
    DaycareQuote quote, {
    int extraBillingPrice = 0,
  }) {
    final int unitPrice = quote.extraUnits > 0 && quote.extraTimeAmount > 0
        ? quote.extraTimeAmount ~/ quote.extraUnits
        : extraBillingPrice;
    return hourlyBillingRuleText(
      includedMinutes: quote.includedMinutes,
      basePrice: quote.baseAmount,
      extraBillingMinutes: quote.extraBillingMinutes,
      extraBillingPrice: unitPrice,
    );
  }

  String hourlyRuleTextFromBooking(Map<String, dynamic> booking) {
    final Map<String, dynamic> snap = readMap(
      booking['daycarePricingSnapshot'],
    );
    final Map<String, dynamic> timeSnap = readMap(
      booking['timeChargeSnapshot'],
    );
    final Map<String, dynamic> plan = readMap(
      booking['daycarePlanPriceSnapshot'] ?? booking['daycarePlanSnapshot'],
    );
    final Map<String, dynamic> room = readMap(
      booking['requestedRoomTypePriceSnapshot'],
    );
    int includedMinutes = readInt(
      snap['includedMinutes'] ?? timeSnap['includedMinutes'],
    );
    if (includedMinutes <= 0) {
      includedMinutes = readInt(
        plan['includedMinutes'] ?? room['includedMinutes'],
      );
    }
    int extraBillingMinutes = readInt(
      snap['extraBillingMinutes'] ?? timeSnap['extraBillingMinutes'],
    );
    if (extraBillingMinutes != 30 && extraBillingMinutes != 60) {
      extraBillingMinutes = readInt(
        plan['extraBillingMinutes'] ?? room['extraBillingMinutes'],
      );
    }
    if (extraBillingMinutes != 30) {
      extraBillingMinutes = 60;
    }
    int basePrice = readInt(snap['baseAmount']);
    if (basePrice <= 0) {
      basePrice = readInt(plan['basePrice'] ?? room['basePrice']);
    }
    int extraBillingPrice = readInt(
      plan['extraBillingPrice'] ?? room['extraBillingPrice'],
    );
    final int extraUnits = readInt(
      snap['extraUnits'] ?? timeSnap['extraUnits'],
    );
    final int extraTimeAmount = readInt(
      snap['extraTimeAmount'] ?? snap['roomTypeExtra'],
    );
    if (extraBillingPrice <= 0 && extraUnits > 0 && extraTimeAmount > 0) {
      extraBillingPrice = extraTimeAmount ~/ extraUnits;
    }
    if (includedMinutes <= 0 && basePrice <= 0) {
      return '';
    }
    return hourlyBillingRuleText(
      includedMinutes: includedMinutes,
      basePrice: basePrice,
      extraBillingMinutes: extraBillingMinutes,
      extraBillingPrice: extraBillingPrice,
    );
  }

  DaycareHourlyDisplayInfo hourlyDisplayFromBooking(
    Map<String, dynamic> booking, {
    DateTime? startAt,
    DateTime? endAt,
  }) {
    final Map<String, dynamic> snap = readMap(
      booking['daycarePricingSnapshot'],
    );
    final Map<String, dynamic> timeSnap = readMap(
      booking['timeChargeSnapshot'],
    );
    final Map<String, dynamic> plan = readMap(
      booking['daycarePlanPriceSnapshot'] ?? booking['daycarePlanSnapshot'],
    );
    final Map<String, dynamic> room = readMap(
      booking['requestedRoomTypePriceSnapshot'],
    );
    final bool roomBased = DaycarePricingModes.isRoomBased(
      (booking['pricingMode'] ?? '').toString(),
    );
    final List<BookingFeeLineItem> itemLines = itemLinesFromBooking(booking);
    final String ruleText = hourlyRuleTextFromBooking(booking);
    int includedMinutes = readInt(
      snap['includedMinutes'] ?? timeSnap['includedMinutes'],
    );
    if (includedMinutes <= 0) {
      includedMinutes = readInt(
        plan['includedMinutes'] ?? room['includedMinutes'],
      );
    }
    int extraBillingMinutes = readInt(
      snap['extraBillingMinutes'] ?? timeSnap['extraBillingMinutes'],
    );
    if (extraBillingMinutes != 30 && extraBillingMinutes != 60) {
      extraBillingMinutes = readInt(
        plan['extraBillingMinutes'] ?? room['extraBillingMinutes'],
      );
    }
    if (extraBillingMinutes != 30) {
      extraBillingMinutes = 60;
    }
    int basePrice = readInt(snap['baseAmount']);
    if (basePrice <= 0) {
      basePrice = readInt(plan['basePrice'] ?? room['basePrice']);
    }
    int extraBillingPrice = readInt(
      plan['extraBillingPrice'] ?? room['extraBillingPrice'],
    );
    final int extraUnits = readInt(
      snap['extraUnits'] ?? timeSnap['extraUnits'],
    );
    final int extraMinutes = readInt(
      snap['extraMinutes'] ?? timeSnap['extraMinutes'],
    );
    final int extraTimeAmount = readInt(
      snap['extraTimeAmount'] ?? snap['roomTypeExtra'],
    );
    if (extraBillingPrice <= 0 && extraUnits > 0 && extraTimeAmount > 0) {
      extraBillingPrice = extraTimeAmount ~/ extraUnits;
    }
    final int durationMinutes = startAt != null && endAt != null
        ? endAt.difference(startAt).inMinutes
        : readInt(snap['durationMinutes'] ?? timeSnap['durationMinutes']);
    final int maxBaseCharge = readInt(
      snap['maxBaseCharge'] ??
          timeSnap['maxBaseCharge'] ??
          plan['maxBaseCharge'] ??
          room['maxBaseCharge'],
    );

    String reservationText = '本次預約：共 ${minutesLabel(durationMinutes)}';
    if (startAt != null && endAt != null) {
      reservationText =
          '本次預約：送達 ${DaycareTimeHelper.formatDateTime(startAt)}、接回 ${DaycareTimeHelper.formatDateTime(endAt)}，共 ${minutesLabel(durationMinutes)}';
    }

    final String startRuleText = includedMinutes > 0 || basePrice > 0
        ? '起步：${includedMinutes > 0 ? minutesLabel(includedMinutes) : '—'}，NT\$ ${basePrice > 0 ? basePrice : '—'}'
        : '';
    final String extraRuleText = extraBillingPrice > 0
        ? '超過後：${extraUnitRateText(extraBillingMinutes: extraBillingMinutes, extraBillingPrice: extraBillingPrice)}'
        : '';

    String thisChargeText = '本次計費：依訂單快照顯示既有金額';
    if (basePrice > 0 && extraTimeAmount > 0) {
      final int shownUnits = extraUnits > 0 ? extraUnits : 1;
      final String billed = extraBillingMinutes == 30
          ? '$shownUnits 個 30 分鐘 × NT\$$extraBillingPrice'
          : '$shownUnits 小時 × NT\$$extraBillingPrice';
      thisChargeText =
          '本次計費：起步費 NT\$$basePrice＋超過起步 ${minutesLabel(extraMinutes > 0 ? extraMinutes : shownUnits * extraBillingMinutes)}（$billed）';
    } else if (basePrice > 0) {
      thisChargeText = '本次計費：起步費 NT\$$basePrice（未超過起步時間）';
    }

    return DaycareHourlyDisplayInfo(
      billingModeLabel: roomBased ? '計費方式：房型計費' : '計費方式：獨立方案',
      ruleText: ruleText,
      startRuleText: startRuleText,
      extraRuleText: extraRuleText,
      reservationText: reservationText,
      thisChargeText: thisChargeText,
      capText: maxBaseCharge > 0 ? '當次最高費用 NT\$$maxBaseCharge' : '',
      itemLines: itemLines,
    );
  }

  String payableLabel(String depositType) {
    switch (depositType) {
      case DaycareDepositTypes.full:
        return '本次應付全額';
      case DaycareDepositTypes.fixed:
      case DaycareDepositTypes.percent:
        return '本次應付訂金';
      default:
        return '到店付款';
    }
  }

  int payableAmount({
    required DaycareQuote quote,
    required String depositType,
  }) {
    switch (depositType) {
      case DaycareDepositTypes.fixed:
      case DaycareDepositTypes.percent:
        return quote.depositAmount;
      default:
        return quote.totalAmount;
    }
  }

  String shopLatePickupExample(DaycareSettingsModel settings) {
    if (!settings.latePickupEnabled || settings.latePickupPrice <= 0) {
      return '目前不收取逾時接回費。';
    }
    return latePickupExample(
      scheduledPickup: settings.latestPickUp,
      graceMinutes: settings.overtimeGraceMinutes,
      unitMinutes: settings.latePickupUnitMinutes,
      unitPrice: settings.latePickupPrice,
    );
  }

  String latePickupExample({
    required String scheduledPickup,
    required int graceMinutes,
    required int unitMinutes,
    required int unitPrice,
  }) {
    final String unitLabel = unitMinutes == 30 ? '每 30 分鐘' : '每 1 小時';
    if (graceMinutes <= 0) {
      return '預定 $scheduledPickup 接回，不寬限；之後$unitLabel加收 NT\$$unitPrice。';
    }
    return '預定 $scheduledPickup 接回，免費寬限至 ${_addMinutes(scheduledPickup, graceMinutes)}；之後$unitLabel加收 NT\$$unitPrice。';
  }

  DaycareLatePickupBreakdown latePickupBreakdown({
    required DaycareSettingsModel settings,
    required DateTime scheduledEndAt,
    required DateTime actualEndAt,
  }) {
    final int extra = actualEndAt.difference(scheduledEndAt).inMinutes < 0
        ? 0
        : actualEndAt.difference(scheduledEndAt).inMinutes;
    final int grace = settings.overtimeGraceMinutes < 0
        ? 0
        : settings.overtimeGraceMinutes;
    final bool enabled =
        settings.latePickupEnabled && settings.latePickupPrice > 0;
    final int unitMinutes = settings.latePickupUnitMinutes == 30 ? 30 : 60;
    final int unitPrice = settings.latePickupPrice;
    final int billableRaw = extra - grace;
    final int billable = billableRaw < 0 ? 0 : billableRaw;
    int units = 0;
    int amount = 0;
    if (enabled && billable > 0 && unitPrice > 0) {
      amount = intervalOvertimeFee(
        extraMinutes: billable,
        unitMinutes: unitMinutes,
        unitPrice: unitPrice,
      );
      units = unitPrice <= 0 ? 0 : amount ~/ unitPrice;
    }
    return DaycareLatePickupBreakdown(
      extraMinutes: extra,
      graceMinutes: grace,
      billableMinutes: billable,
      unitMinutes: unitMinutes,
      unitPrice: unitPrice,
      units: units,
      amount: amount,
      enabled: enabled,
    );
  }

  int shopLatePickupFee({
    required DaycareSettingsModel settings,
    required DateTime scheduledEndAt,
    required DateTime actualEndAt,
  }) {
    return latePickupBreakdown(
      settings: settings,
      scheduledEndAt: scheduledEndAt,
      actualEndAt: actualEndAt,
    ).amount;
  }

  DaycareQuote quote({
    required DaycareSettingsModel settings,
    required DaycarePlanModel plan,
    required DateTime startAt,
    required DateTime endAt,
    required int petCount,
    int roomTypeExtra = 0,
    int addonAmount = 0,
    int surchargeAmount = 0,
    int discountAmount = 0,
    int couponAmount = 0,
    int pointAmount = 0,
    int overtimeAmount = 0,
    int manualAdjust = 0,
  }) {
    final int minutes = endAt.difference(startAt).inMinutes;
    final DaycareTimeCharge charge = quoteTimeCharge(
      includedMinutes: plan.includedMinutes,
      basePrice: plan.basePrice,
      extraBillingMinutes: plan.extraBillingMinutes,
      extraBillingPrice: plan.extraBillingPrice,
      extraPetPrice: plan.extraPetPrice,
      maxBaseCharge: plan.maxBaseCharge,
      durationMinutes: minutes,
      petCount: petCount,
    );
    int total =
        charge.timeCharge +
        charge.extraPetCharge +
        roomTypeExtra +
        addonAmount +
        surchargeAmount +
        overtimeAmount +
        manualAdjust -
        discountAmount -
        couponAmount -
        pointAmount;
    if (total < 0) {
      total = 0;
    }
    final int deposit = _deposit(settings: settings, total: total);
    return DaycareQuote(
      durationMinutes: charge.durationMinutes,
      baseAmount: plan.basePrice,
      extraPetAmount: charge.extraPetCharge,
      roomTypeExtra: roomTypeExtra,
      addonAmount: addonAmount,
      surchargeAmount: surchargeAmount,
      discountAmount: discountAmount,
      couponAmount: couponAmount,
      pointAmount: pointAmount,
      overtimeAmount: overtimeAmount,
      manualAdjust: manualAdjust,
      totalAmount: total,
      depositAmount: deposit,
      extraTimeAmount: charge.extraUnits * plan.extraBillingPrice,
      extraMinutes: charge.extraMinutes,
      extraUnits: charge.extraUnits,
      includedMinutes: charge.includedMinutes,
      extraBillingMinutes: charge.extraBillingMinutes,
      extraPetCount: charge.extraPetCount,
      timeCharge: charge.timeCharge,
      maxBaseCharge: charge.maxBaseCharge,
      uncappedTimeCharge: charge.uncappedTimeCharge,
    );
  }

  DaycareQuote quoteFromRoom({
    required DaycareSettingsModel settings,
    required DaycareRoomQuote room,
    int addonAmount = 0,
    int surchargeAmount = 0,
    int discountAmount = 0,
    int couponAmount = 0,
    int pointAmount = 0,
    int overtimeAmount = 0,
    int manualAdjust = 0,
  }) {
    int total =
        room.cappedRoomAmount +
        addonAmount +
        surchargeAmount +
        overtimeAmount +
        manualAdjust -
        discountAmount -
        couponAmount -
        pointAmount;
    if (total < 0) {
      total = 0;
    }
    return DaycareQuote(
      durationMinutes: room.durationMinutes,
      baseAmount: room.baseAmount,
      extraPetAmount: room.extraPetAmount,
      roomTypeExtra: room.extraTimeAmount,
      addonAmount: addonAmount,
      surchargeAmount: surchargeAmount,
      discountAmount: discountAmount,
      couponAmount: couponAmount,
      pointAmount: pointAmount,
      overtimeAmount: overtimeAmount,
      manualAdjust: manualAdjust,
      totalAmount: total,
      depositAmount: _deposit(settings: settings, total: total),
      extraTimeAmount: room.extraTimeAmount,
      extraMinutes: room.extraMinutes,
      extraUnits: room.extraUnits,
      includedMinutes: room.includedMinutes,
      extraBillingMinutes: room.extraBillingMinutes,
      extraPetCount: room.extraPetCount,
      timeCharge: room.timeCharge,
      maxBaseCharge: room.maxBaseCharge,
      uncappedTimeCharge: room.uncappedTimeCharge,
    );
  }

  int addonLineAmount({
    required Map<String, dynamic> addon,
    required int minutes,
    required int petCount,
  }) {
    final int price = _toInt(addon['price'], 0);
    final String mode = (addon['daycareChargeMode'] ?? 'per_order').toString();
    final int qty = _toInt(addon['count'], 1).clamp(1, 99);
    if (mode == 'per_pet') {
      return price * petCount.clamp(1, 99);
    }
    if (mode == 'per_hour') {
      return price * (minutes / 60).ceil().clamp(1, 99);
    }
    if (mode == 'per_slot') {
      return price * _toInt(addon['slotCount'], 1).clamp(1, 99);
    }
    if (mode == 'custom') {
      return price * qty;
    }
    return price;
  }

  int overtimeFee({
    required DaycarePlanModel plan,
    required DaycareSettingsModel settings,
    required DateTime scheduledEndAt,
    required DateTime actualEndAt,
  }) {
    final int extra = actualEndAt
        .difference(scheduledEndAt)
        .inMinutes
        .clamp(0, 24 * 60);
    final int billable = extra - settings.overtimeGraceMinutes;
    if (billable <= 0 || plan.overtimeMode == DaycareOvertimeModes.none) {
      return 0;
    }
    if (plan.overtimeMode == DaycareOvertimeModes.halfHourly) {
      final int units = (billable / 30).ceil();
      return units * plan.overtimeUnitPrice;
    }
    final int units = (billable / 60).ceil();
    return units * plan.overtimeUnitPrice;
  }

  int extraTimeAmount({
    required int extraMinutes,
    required int unitMinutes,
    required int unitPrice,
    required String roundingMode,
  }) {
    if (extraMinutes <= 0 || unitPrice <= 0) {
      return 0;
    }
    final int unit = unitMinutes == 15 || unitMinutes == 30 || unitMinutes == 60
        ? unitMinutes
        : 60;
    if (roundingMode == DaycareRoundingModes.prorated) {
      return roundMoney(extraMinutes / unit * unitPrice);
    }
    if (roundingMode == DaycareRoundingModes.ceilHalfHour) {
      final int pricePerHalf = unit == 30
          ? unitPrice
          : roundMoney(unitPrice * 30 / unit);
      return (extraMinutes / 30).ceil() * pricePerHalf;
    }
    final int pricePerHour = unit == 60
        ? unitPrice
        : roundMoney(unitPrice * 60 / unit);
    return (extraMinutes / 60).ceil() * pricePerHour;
  }

  /// 超時費：超過寬限後，每滿一個計價區間收一次，不足一區間以一區間計。
  int intervalOvertimeFee({
    required int extraMinutes,
    required int unitMinutes,
    required int unitPrice,
  }) {
    if (extraMinutes <= 0 || unitPrice <= 0) {
      return 0;
    }
    final int unit = unitMinutes == 15 || unitMinutes == 30 || unitMinutes == 60
        ? unitMinutes
        : 60;
    return (extraMinutes / unit).ceil() * unitPrice;
  }

  int resolvedOvertimeGraceMinutes({
    required DaycareSettingsModel settings,
    required DaycareRoomTypeSetting roomSetting,
  }) {
    if (roomSetting.overtimeGraceMinutes > 0) {
      return roomSetting.overtimeGraceMinutes;
    }
    return settings.overtimeGraceMinutes;
  }

  String overtimeRuleSummary({
    required DaycareSettingsModel settings,
    DaycareRoomTypeSetting? roomSetting,
  }) {
    if (settings.latePickupEnabled && settings.latePickupPrice > 0) {
      return shopLatePickupExample(settings);
    }
    if (roomSetting == null ||
        !roomSetting.overtimeEnabled ||
        roomSetting.latePickupPrice <= 0) {
      return '';
    }
    return latePickupExample(
      scheduledPickup: settings.latestPickUp,
      graceMinutes: resolvedOvertimeGraceMinutes(
        settings: settings,
        roomSetting: roomSetting,
      ),
      unitMinutes: roomSetting.latePickupUnitMinutes,
      unitPrice: roomSetting.latePickupPrice,
    );
  }

  String _addMinutes(String hhmm, int minutes) {
    final int total = DaycareTimeHelper.minutesOf(hhmm) + minutes;
    final int clamped = total.clamp(0, 24 * 60 - 1);
    final String h = (clamped ~/ 60).toString().padLeft(2, '0');
    final String m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  int estimatedLatePickupFee({
    required DaycareSettingsModel settings,
    required DaycareRoomTypeSetting roomSetting,
    required DateTime endAt,
  }) {
    // 逾時接回費只在實際接回後結算，下單前不預估。
    return 0;
  }

  int estimatedPlanLatePickupFee({
    required DaycareSettingsModel settings,
    required DaycarePlanModel plan,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (plan.overtimeMode == DaycareOvertimeModes.none ||
        plan.overtimeUnitPrice <= 0) {
      return 0;
    }
    final int closeMinutes = DaycareTimeHelper.minutesOf(settings.latestPickUp);
    final DateTime closeAt = DateTime(
      endAt.year,
      endAt.month,
      endAt.day,
      closeMinutes ~/ 60,
      closeMinutes % 60,
    );
    final int extra =
        endAt.difference(closeAt).inMinutes - settings.overtimeGraceMinutes;
    if (extra <= 0) {
      return 0;
    }
    if (plan.overtimeMode == DaycareOvertimeModes.halfHourly) {
      return (extra / 30).ceil() * plan.overtimeUnitPrice;
    }
    return (extra / 60).ceil() * plan.overtimeUnitPrice;
  }

  int billableMinutesBeforeClose({
    required DaycareSettingsModel settings,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final int closeMinutes = DaycareTimeHelper.minutesOf(settings.latestPickUp);
    final DateTime closeAt = DateTime(
      endAt.year,
      endAt.month,
      endAt.day,
      closeMinutes ~/ 60,
      closeMinutes % 60,
    );
    final DateTime cappedEnd = endAt.isAfter(closeAt) ? closeAt : endAt;
    final int minutes = cappedEnd.difference(startAt).inMinutes;
    return minutes < 0 ? 0 : minutes;
  }

  int overnightStayOriginal({
    required int roomNightPrice,
    required int extraPetNightPrice,
    required int petCount,
    int specialDateSurcharge = 0,
  }) {
    final int extraPets = (petCount - 1).clamp(0, 99);
    return roomNightPrice +
        extraPets * extraPetNightPrice +
        specialDateSurcharge.clamp(0, 999999);
  }

  int applyCap({
    required int amount,
    required String capMode,
    required int capAmount,
  }) {
    if (capMode == DaycareCapModes.none || capAmount <= 0) {
      return amount < 0 ? 0 : amount;
    }
    if (amount <= capAmount) {
      return amount < 0 ? 0 : amount;
    }
    return capAmount;
  }

  DaycareRoomQuote quoteRoom({
    required DaycareRoomTypeSetting roomSetting,
    required DateTime startAt,
    required DateTime endAt,
    required int petCount,
    int overnightCapAmount = 0,
  }) {
    final int minutes = endAt.difference(startAt).inMinutes;
    final DaycareTimeCharge charge = quoteTimeCharge(
      includedMinutes: roomSetting.includedMinutes,
      basePrice: roomSetting.basePrice,
      extraBillingMinutes: roomSetting.extraBillingMinutes,
      extraBillingPrice: roomSetting.extraBillingPrice,
      extraPetPrice: roomSetting.extraPetPrice,
      maxBaseCharge: roomSetting.maxBaseCharge,
      durationMinutes: minutes,
      petCount: petCount,
    );
    return DaycareRoomQuote(
      durationMinutes: charge.durationMinutes,
      baseAmount: roomSetting.basePrice,
      extraPetAmount: charge.extraPetCharge,
      extraTimeAmount: charge.extraUnits * roomSetting.extraBillingPrice,
      uncappedRoomAmount: charge.uncappedTimeCharge + charge.extraPetCharge,
      capAmount: charge.maxBaseCharge,
      cappedRoomAmount: charge.subtotal,
      roundingMode: roomSetting.roundingMode,
      capMode: roomSetting.capMode,
      extraMinutes: charge.extraMinutes,
      extraUnits: charge.extraUnits,
      includedMinutes: charge.includedMinutes,
      extraBillingMinutes: charge.extraBillingMinutes,
      extraPetCount: charge.extraPetCount,
      timeCharge: charge.timeCharge,
      maxBaseCharge: charge.maxBaseCharge,
      uncappedTimeCharge: charge.uncappedTimeCharge,
    );
  }

  int estimateFromPrice({
    required DaycareSettingsModel settings,
    required DateTime startAt,
    required DateTime endAt,
    required int petCount,
  }) {
    int? minPrice;
    for (final DaycareRoomTypeSetting item
        in settings.enabledRoomTypeSettings) {
      final DaycareRoomQuote q = quoteRoom(
        roomSetting: item,
        startAt: startAt,
        endAt: endAt,
        petCount: petCount,
      );
      minPrice = minPrice == null
          ? q.cappedRoomAmount
          : (q.cappedRoomAmount < minPrice ? q.cappedRoomAmount : minPrice);
    }
    return minPrice ?? 0;
  }

  DaycareSettlement settle({
    required DaycareSettingsModel settings,
    required Map<String, dynamic> booking,
    required DateTime actualEndAt,
    bool waiveOvertime = false,
    int overnightCapAmount = 0,
    int manualAdjust = 0,
  }) {
    final DateTime scheduledEnd = booking['scheduledEndAt'] is DateTime
        ? booking['scheduledEndAt'] as DateTime
        : actualEndAt;
    final int quoted = _toInt(
      booking['quotedTotalPrice'] ?? booking['totalPrice'],
      0,
    );
    final int paid = _toInt(booking['paidAmount'], 0);
    final DaycareLatePickupBreakdown pickup = latePickupBreakdown(
      settings: settings,
      scheduledEndAt: scheduledEnd,
      actualEndAt: actualEndAt,
    );
    final int overtimeAmount = waiveOvertime ? 0 : pickup.amount;
    String roundingLabel = pickup.formula;
    if (waiveOvertime) {
      roundingLabel = '店家免收本次超時費';
    }
    final int finalTotal = quoted + overtimeAmount + manualAdjust < 0
        ? 0
        : quoted + overtimeAmount + manualAdjust;
    return DaycareSettlement(
      quotedTotal: quoted,
      overtimeMinutes: pickup.extraMinutes,
      overtimeAmount: overtimeAmount,
      capAmount: overnightCapAmount,
      finalTotal: finalTotal,
      paidAmount: paid,
      waivedOvertime: waiveOvertime,
      roundingLabel: roundingLabel,
    );
  }

  int _deposit({required DaycareSettingsModel settings, required int total}) {
    switch (settings.depositType) {
      case DaycareDepositTypes.full:
        return total;
      case DaycareDepositTypes.fixed:
        return settings.depositValue.clamp(0, total);
      case DaycareDepositTypes.percent:
        return roundMoney(total * settings.depositValue / 100).clamp(0, total);
      default:
        return 0;
    }
  }

  static int _toInt(dynamic raw, int fallback) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }
}
