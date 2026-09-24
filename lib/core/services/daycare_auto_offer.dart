// 檔案名稱：lib/core/services/daycare_auto_offer.dart
// 功能說明：安親自動優惠與特殊日期加價，與住宿共用 DiscountCampaignCalculator。

import '../models/discount_campaign_model.dart';
import '../models/policy_applicable_service.dart';
import '../models/special_date_surcharge_model.dart';
import 'discount_campaign_calculator.dart';
import 'special_date_surcharge_calculator.dart';

class DaycareAutoOffer {
  const DaycareAutoOffer({
    required this.surchargeAmount,
    required this.allowCampaign,
    required this.allowCoupon,
    this.campaign,
  });

  final int surchargeAmount;
  final bool allowCampaign;
  final bool allowCoupon;
  final DiscountCampaignCalculationResult? campaign;

  int get campaignAmount => campaign?.discountAmount ?? 0;

  String get campaignId => campaign?.campaign.id ?? '';

  String get campaignName => campaign?.campaign.name ?? '';

  String get campaignDescription => campaign?.campaign.description ?? '';

  String get campaignType => campaign?.campaign.type.name ?? '';
}

class DaycareAutoOfferResolver {
  DaycareAutoOfferResolver._();

  static DaycareAutoOffer resolve({
    required DateTime serviceStartAt,
    required bool isRoomBased,
    required String roomTypeId,
    required String planId,
    required int planAmount,
    required int extraPetAmount,
    required int addonAmount,
    required List<SpecialDateSurchargeModel> surcharges,
    required List<DiscountCampaignModel> campaigns,
    bool isFirstBooking = false,
    DateTime? memberJoinedAt,
    Map<String, int> memberCampaignUsage = const <String, int>{},
    Map<String, int> memberCampaignUsedNights = const <String, int>{},
    bool hasVerifiedGoogleReview = false,
    DateTime? now,
  }) {
    final SpecialDateSurchargeCalculationResult surchargeResult =
        SpecialDateSurchargeCalculator.calculateDaycare(
          serviceDate: serviceStartAt,
          isRoomBased: isRoomBased,
          roomTypeId: roomTypeId,
          surcharges: surcharges,
        );
    final bool allowCampaign = surchargeResult.nightDetails.every(
      (SpecialDateSurchargeNightDetail detail) => detail.surcharges.every(
        (SpecialDateSurchargeModel item) => item.allowCampaignDiscount,
      ),
    );
    final bool allowCoupon = surchargeResult.nightDetails.every(
      (SpecialDateSurchargeNightDetail detail) => detail.surcharges.every(
        (SpecialDateSurchargeModel item) => item.allowCoupon,
      ),
    );
    DiscountCampaignCalculationResult? best;
    if (allowCampaign && campaigns.isNotEmpty) {
      final DateTime checkIn = DateTime(
        serviceStartAt.year,
        serviceStartAt.month,
        serviceStartAt.day,
      );
      best = DiscountCampaignCalculator.findBestCampaign(
        campaigns: campaigns,
        now: now,
        input: DiscountCampaignCalculationInput(
          checkInDate: checkIn,
          checkOutDate: checkIn.add(const Duration(days: 1)),
          roomTypeId: isRoomBased ? roomTypeId : planId,
          roomAmount: planAmount + surchargeResult.totalAmount,
          petAmount: extraPetAmount,
          extraServiceAmount: addonAmount,
          isFirstBooking: isFirstBooking,
          memberJoinedAt: memberJoinedAt,
          hasVerifiedGoogleReview: hasVerifiedGoogleReview,
          memberCampaignUsage: memberCampaignUsage,
          memberCampaignUsedNights: memberCampaignUsedNights,
          serviceType: PolicyApplicableService.daycare,
        ),
      );
    }
    return DaycareAutoOffer(
      surchargeAmount: surchargeResult.totalAmount,
      allowCampaign: allowCampaign,
      allowCoupon: allowCoupon,
      campaign: best,
    );
  }
}
