// lib/core/services/daycare_pricing_service.dart
// 🐾 臨托計價：前台、手動訂單與測試共用同一套公式。
// 金額一律四捨五入為整數新台幣。

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

class DaycarePricingService {
  DaycarePricingService._();

  static final DaycarePricingService instance = DaycarePricingService._();

  static int roundMoney(num value) => value.round();

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
      roomTypeExtra: charge.timeCharge - plan.basePrice,
      addonAmount: addonAmount,
      surchargeAmount: surchargeAmount,
      discountAmount: discountAmount,
      couponAmount: couponAmount,
      pointAmount: pointAmount,
      overtimeAmount: overtimeAmount,
      manualAdjust: manualAdjust,
      totalAmount: total,
      depositAmount: deposit,
      extraTimeAmount: charge.timeCharge - plan.basePrice,
      extraMinutes: charge.extraMinutes,
      extraUnits: charge.extraUnits,
      includedMinutes: charge.includedMinutes,
      extraBillingMinutes: charge.extraBillingMinutes,
      extraPetCount: charge.extraPetCount,
      timeCharge: charge.timeCharge,
      maxBaseCharge: charge.maxBaseCharge,
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
      extraMinutes: 0,
      extraUnits: 0,
      includedMinutes: 0,
      extraBillingMinutes: 60,
      extraPetCount: room.extraPetAmount > 0 ? 1 : 0,
      timeCharge: room.baseAmount + room.extraTimeAmount,
      maxBaseCharge: room.capAmount,
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
    required DaycareRoomTypeSetting roomSetting,
  }) {
    if (!roomSetting.overtimeEnabled || roomSetting.latePickupPrice <= 0) {
      return '';
    }
    final int grace = resolvedOvertimeGraceMinutes(
      settings: settings,
      roomSetting: roomSetting,
    );
    final String unitLabel = roomSetting.latePickupUnitMinutes == 30
        ? '每 30 分鐘'
        : '每 1 小時';
    final String graceLabel = grace <= 0
        ? '不寬限'
        : '免費寬限至 ${_addMinutes(settings.latestPickUp, grace)}';
    if (grace <= 0) {
      return '預定 ${settings.latestPickUp} 接回，不寬限；之後$unitLabel加收 NT\$${roomSetting.latePickupPrice}。';
    }
    return '預定 ${settings.latestPickUp} 接回，$graceLabel；之後$unitLabel加收 NT\$${roomSetting.latePickupPrice}。';
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
    if (!roomSetting.overtimeEnabled || roomSetting.latePickupPrice <= 0) {
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
    final int grace = resolvedOvertimeGraceMinutes(
      settings: settings,
      roomSetting: roomSetting,
    );
    final int extra = endAt.difference(closeAt).inMinutes - grace;
    if (extra <= 0) {
      return 0;
    }
    return intervalOvertimeFee(
      extraMinutes: extra,
      unitMinutes: roomSetting.latePickupUnitMinutes,
      unitPrice: roomSetting.latePickupPrice,
    );
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
      extraTimeAmount: charge.timeCharge - roomSetting.basePrice,
      uncappedRoomAmount: charge.uncappedTimeCharge + charge.extraPetCharge,
      capAmount: charge.maxBaseCharge,
      cappedRoomAmount: charge.subtotal,
      roundingMode: roomSetting.roundingMode,
      capMode: roomSetting.capMode,
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
    DaycarePlanModel? plan,
  }) {
    final DateTime scheduledEnd = booking['scheduledEndAt'] is DateTime
        ? booking['scheduledEndAt'] as DateTime
        : DateTime.now();
    final int quoted = _toInt(
      booking['quotedTotalPrice'] ?? booking['totalPrice'],
      0,
    );
    final int paid = _toInt(booking['paidAmount'], 0);
    final int overtimeMinutes = actualEndAt
        .difference(scheduledEnd)
        .inMinutes
        .clamp(0, 24 * 60);
    int overtimeAmount = 0;
    String roundingLabel = '未超時';
    final bool roomBased = DaycarePricingModes.isRoomBased(
      (booking['pricingMode'] ?? settings.pricingMode).toString(),
    );
    if (!waiveOvertime && overtimeMinutes > settings.overtimeGraceMinutes) {
      if (roomBased) {
        final String roomTypeId = (booking['roomTypeId'] ?? '').toString();
        final DaycareRoomTypeSetting roomSetting =
            settings.roomTypeSetting(roomTypeId) ??
            const DaycareRoomTypeSetting(roomTypeId: '');
        overtimeAmount = extraTimeAmount(
          extraMinutes: overtimeMinutes - settings.overtimeGraceMinutes,
          unitMinutes: roomSetting.extraTimeUnitMinutes,
          unitPrice: roomSetting.extraTimePrice,
          roundingMode: roomSetting.roundingMode,
        );
        roundingLabel = _roundingLabel(roomSetting.roundingMode);
        final Map<String, dynamic> snap = booking['priceQuoteSnapshot'] is Map
            ? Map<String, dynamic>.from(booking['priceQuoteSnapshot'] as Map)
            : const <String, dynamic>{};
        final int quotedRoom = _toInt(
          snap['cappedRoomAmount'] ?? quoted,
          quoted,
        );
        final int cap = roomSetting.capMode == DaycareCapModes.fixedAmount
            ? roomSetting.fixedCapAmount
            : _toInt(
                snap['overnightCapAmount'] ?? overnightCapAmount,
                overnightCapAmount,
              );
        final int newRoom = applyCap(
          amount: quotedRoom + overtimeAmount,
          capMode: roomSetting.capMode,
          capAmount: cap,
        );
        overtimeAmount = (newRoom - quotedRoom).clamp(0, 999999);
        final int addonKeep = quoted - quotedRoom;
        final int finalTotal = newRoom + addonKeep;
        return DaycareSettlement(
          quotedTotal: quoted,
          overtimeMinutes: overtimeMinutes,
          overtimeAmount: overtimeAmount,
          capAmount: roomSetting.capMode == DaycareCapModes.none ? 0 : cap,
          finalTotal: finalTotal < quoted ? quoted : finalTotal,
          paidAmount: paid,
          waivedOvertime: false,
          roundingLabel: roundingLabel,
        );
      } else if (plan != null) {
        overtimeAmount = overtimeFee(
          plan: plan,
          settings: settings,
          scheduledEndAt: scheduledEnd,
          actualEndAt: actualEndAt,
        );
        roundingLabel = plan.overtimeMode == DaycareOvertimeModes.halfHourly
            ? '不足半小時以半小時計'
            : '不足一小時以整小時計';
      }
    }
    final int finalTotal = quoted + (waiveOvertime ? 0 : overtimeAmount);
    return DaycareSettlement(
      quotedTotal: quoted,
      overtimeMinutes: overtimeMinutes,
      overtimeAmount: waiveOvertime ? 0 : overtimeAmount,
      capAmount: overnightCapAmount,
      finalTotal: finalTotal,
      paidAmount: paid,
      waivedOvertime: waiveOvertime,
      roundingLabel: roundingLabel,
    );
  }

  String _roundingLabel(String mode) {
    switch (mode) {
      case DaycareRoundingModes.ceilHalfHour:
        return '不足半小時，以半小時計';
      case DaycareRoundingModes.prorated:
        return '依實際分鐘比例計價，四捨五入為整數元';
      default:
        return '不足一小時，以整小時計';
    }
  }

  int _baseAmount({required DaycarePlanModel plan, required int minutes}) {
    switch (plan.type) {
      case DaycarePlanTypes.halfHourly:
        final int units = (minutes / 30).ceil().clamp(plan.minChargeUnits, 999);
        return units * plan.basePrice;
      case DaycarePlanTypes.hourly:
        final int units = (minutes / 60).ceil().clamp(plan.minChargeUnits, 999);
        return units * plan.basePrice;
      case DaycarePlanTypes.fixedHours:
      case DaycarePlanTypes.morning:
      case DaycarePlanTypes.afternoon:
      case DaycarePlanTypes.fullDay:
      case DaycarePlanTypes.custom:
        int amount = plan.basePrice;
        if (minutes > plan.includedMinutes &&
            plan.overtimeMode != DaycareOvertimeModes.none) {
          final int extra = minutes - plan.includedMinutes;
          if (plan.overtimeMode == DaycareOvertimeModes.halfHourly) {
            amount += (extra / 30).ceil() * plan.overtimeUnitPrice;
          } else {
            amount += (extra / 60).ceil() * plan.overtimeUnitPrice;
          }
        }
        return amount;
      default:
        return plan.basePrice;
    }
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
