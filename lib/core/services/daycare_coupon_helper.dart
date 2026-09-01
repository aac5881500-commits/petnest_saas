// lib/core/services/daycare_coupon_helper.dart
// 🐾 臨托優惠券：是否適用與折扣金額，前後端同一套規則

import 'package:petnest_saas/core/models/member_coupon_model.dart';

class DaycareCouponHelper {
  DaycareCouponHelper._();

  static bool appliesToDaycare(MemberCouponModel coupon) {
    if (!coupon.canUseNow) {
      return false;
    }
    if (coupon.type == MemberCouponType.freeStay) {
      return false;
    }
    return true;
  }

  static bool matchesRoomType({
    required MemberCouponModel coupon,
    required String roomTypeId,
  }) {
    if (coupon.roomTypeIds.isEmpty) {
      return true;
    }
    return coupon.roomTypeIds.contains(roomTypeId);
  }

  static int discountAmount({
    required MemberCouponModel coupon,
    required int planAmount,
    required int extraPetAmount,
    required int addonAmount,
    required int surchargeAmount,
    required int campaignDiscountAmount,
    required List<Map<String, dynamic>> selectedAddons,
    required bool specialDateAllowsCoupon,
  }) {
    if (!appliesToDaycare(coupon)) {
      return 0;
    }
    if (!specialDateAllowsCoupon) {
      return 0;
    }
    if (coupon.minimumAmount > 0) {
      final int orderAmount =
          planAmount + extraPetAmount + addonAmount + surchargeAmount;
      if (orderAmount < coupon.minimumAmount) {
        return 0;
      }
    }

    final int afterCampaign =
        (planAmount +
                extraPetAmount +
                addonAmount +
                surchargeAmount -
                campaignDiscountAmount)
            .clamp(0, 1 << 30);

    int base;
    switch (coupon.applyTarget) {
      case MemberCouponApplyTarget.room:
        base = (planAmount - campaignDiscountAmount).clamp(0, afterCampaign);
      case MemberCouponApplyTarget.roomAndPet:
        base = (planAmount + extraPetAmount - campaignDiscountAmount).clamp(
          0,
          afterCampaign,
        );
      case MemberCouponApplyTarget.total:
        base = afterCampaign;
      case MemberCouponApplyTarget.service:
        base = _serviceAmount(coupon, selectedAddons);
    }

    int amount = 0;
    switch (coupon.type) {
      case MemberCouponType.fixedAmount:
        amount = coupon.discountValue.toInt().clamp(0, base);
      case MemberCouponType.percent:
        amount = (base * coupon.discountValue / 100).round().clamp(0, base);
        if (coupon.maximumDiscountAmount > 0 &&
            amount > coupon.maximumDiscountAmount) {
          amount = coupon.maximumDiscountAmount;
        }
      case MemberCouponType.freeStay:
        amount = 0;
      case MemberCouponType.freeService:
        amount = _serviceAmount(coupon, selectedAddons).clamp(0, afterCampaign);
    }
    return amount.clamp(0, afterCampaign);
  }

  static int _serviceAmount(
    MemberCouponModel coupon,
    List<Map<String, dynamic>> selectedAddons,
  ) {
    final String serviceId = coupon.serviceId.trim();
    if (serviceId.isEmpty) {
      return 0;
    }
    for (final Map<String, dynamic> addon in selectedAddons) {
      if ((addon['id'] ?? '').toString().trim() != serviceId) {
        continue;
      }
      final num amount = (addon['amount'] ?? addon['price'] ?? 0) as num;
      return amount.round();
    }
    return 0;
  }
}
