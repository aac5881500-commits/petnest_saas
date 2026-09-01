// lib/core/services/daycare_pricing_service.dart
// 🐾 臨托計價：前台、手動訂單與測試共用同一套公式。
// 金額一律四捨五入為整數新台幣。

import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';

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

  int get remainingAmount =>
      (totalAmount - depositAmount).clamp(0, totalAmount);
}

class DaycarePricingService {
  DaycarePricingService._();

  static final DaycarePricingService instance = DaycarePricingService._();

  static int roundMoney(num value) => value.round();

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
    final int safeMinutes = minutes < 0 ? 0 : minutes;
    final int extraPets = (petCount - 1).clamp(0, 99);
    final int extraPetAmount = extraPets * plan.extraPetSurcharge;
    final int baseAmount = _baseAmount(plan: plan, minutes: safeMinutes);
    int total =
        baseAmount +
        extraPetAmount +
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
      durationMinutes: safeMinutes,
      baseAmount: baseAmount,
      extraPetAmount: extraPetAmount,
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
