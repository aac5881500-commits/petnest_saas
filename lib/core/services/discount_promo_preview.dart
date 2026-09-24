// 檔案名稱：lib/core/services/discount_promo_preview.dart
// 功能說明：建立／編輯優惠與加價時的唯讀示意預覽，不寫入訂單。

import '../models/discount_campaign_model.dart';
import '../models/policy_applicable_service.dart';
import 'discount_campaign_calculator.dart';
import 'discount_campaign_customer_copy.dart';

class DiscountPromoPreviewLine {
  const DiscountPromoPreviewLine({required this.label, required this.amount});

  final String label;
  final int amount;
}

class DiscountPromoPreview {
  DiscountPromoPreview._();

  static const int sampleStayNights = 2;
  static const int sampleStayBase = 3000;

  static List<DiscountPromoPreviewLine> forSurcharge({
    required int amountPerNight,
    required List<String> applicableServices,
  }) {
    final bool stay = PolicyApplicableService.appliesTo(
      applicableServices,
      PolicyApplicableService.accommodation,
    );
    final int surcharge = amountPerNight < 0 ? 0 : amountPerNight;
    final int campaignSample = ((sampleStayBase + surcharge) * 0.1).round();
    return <DiscountPromoPreviewLine>[
      const DiscountPromoPreviewLine(
        label: '住宿 $sampleStayNights 晚 NT\$$sampleStayBase',
        amount: sampleStayBase,
      ),
      DiscountPromoPreviewLine(
        label: stay ? '特殊日期加價 +NT\$$surcharge' : '特殊日期加價（每次）+NT\$$surcharge',
        amount: surcharge,
      ),
      DiscountPromoPreviewLine(
        label: '滿額優惠 -NT\$$campaignSample',
        amount: -campaignSample,
      ),
      DiscountPromoPreviewLine(
        label: '應付金額 NT\$${sampleStayBase + surcharge - campaignSample}',
        amount: sampleStayBase + surcharge - campaignSample,
      ),
    ];
  }

  static List<DiscountPromoPreviewLine> forCampaign(
    DiscountCampaignModel campaign,
  ) {
    final DateTime checkIn = DateTime(2026, 9, 28);
    final DiscountCampaignCalculationInput input =
        DiscountCampaignCalculationInput(
          checkInDate: checkIn,
          checkOutDate: checkIn.add(const Duration(days: sampleStayNights)),
          roomTypeId: campaign.roomTypeIds.isEmpty
              ? 'preview-room'
              : campaign.roomTypeIds.first,
          roomAmount: sampleStayBase,
          petAmount: 0,
          extraServiceAmount: 0,
          isFirstBooking: true,
          memberJoinedAt: checkIn,
          serviceType: campaign.appliesToAccommodation
              ? PolicyApplicableService.accommodation
              : PolicyApplicableService.daycare,
        );
    final DiscountCampaignCalculationResult? result =
        DiscountCampaignCalculator.calculateCampaign(
          campaign: campaign.copyWith(enabled: true),
          input: input,
          now: campaign.startAt ?? checkIn,
        );
    final int discount = result?.discountAmount ?? 0;
    return <DiscountPromoPreviewLine>[
      const DiscountPromoPreviewLine(
        label: '住宿 $sampleStayNights 晚 NT\$$sampleStayBase',
        amount: sampleStayBase,
      ),
      DiscountPromoPreviewLine(
        label: '${campaign.name} -NT\$$discount',
        amount: -discount,
      ),
      DiscountPromoPreviewLine(
        label: '應付金額 NT\$${sampleStayBase - discount}',
        amount: sampleStayBase - discount,
      ),
    ];
  }

  static String campaignBenefit(DiscountCampaignModel campaign) {
    return DiscountCampaignCustomerCopy.benefitLine(campaign);
  }
}
