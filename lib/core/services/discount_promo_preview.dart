// 檔案名稱：lib/core/services/discount_promo_preview.dart
// 功能說明：建立／編輯優惠與加價時的唯讀示意預覽，不寫入訂單。

import '../models/discount_campaign_model.dart';
import '../models/policy_applicable_service.dart';
import 'discount_campaign_calculator.dart';
import 'discount_campaign_customer_copy.dart';
import 'shop_report_format.dart';

enum DiscountPromoPreviewKind { base, surcharge, discount, hint, total }

class DiscountPromoPreviewLine {
  const DiscountPromoPreviewLine({
    required this.label,
    required this.amount,
    this.kind = DiscountPromoPreviewKind.base,
    this.chip = '',
  });

  final String label;
  final int amount;
  final DiscountPromoPreviewKind kind;
  final String chip;
}

class DiscountPromoPreviewResult {
  const DiscountPromoPreviewResult({
    required this.heading,
    required this.lines,
    this.badges = const <String>[],
    this.footer = '此為設定示意，實際金額依訂單日期、服務、房型／方案、加購與優惠資格計算。',
  });

  final String heading;
  final List<String> badges;
  final List<DiscountPromoPreviewLine> lines;
  final String footer;
}

class DiscountPromoPreview {
  DiscountPromoPreview._();

  static const int sampleStayNights = 2;
  static const int sampleStayBase = 3000;
  static const int sampleDaycareBase = 1200;
  static const int sampleCampaignDiscount = 350;

  static String nt(int amount) => 'NT\$${ShopReportFormat.number(amount)}';

  static DiscountPromoPreviewResult forSurcharge({
    required int stayAmountPerNight,
    required int daycareAmountPerSession,
    required List<String> applicableServices,
    required bool enabled,
    required bool allowCampaignDiscount,
    required bool allowCoupon,
    required bool previewDaycare,
  }) {
    final bool stay = PolicyApplicableService.appliesTo(
      applicableServices,
      PolicyApplicableService.accommodation,
    );
    final bool daycare = PolicyApplicableService.appliesTo(
      applicableServices,
      PolicyApplicableService.daycare,
    );
    final bool useDaycare = previewDaycare && daycare;
    final int base = useDaycare ? sampleDaycareBase : sampleStayBase;
    final int unit = useDaycare
        ? (daycareAmountPerSession < 0 ? 0 : daycareAmountPerSession)
        : (stayAmountPerNight < 0 ? 0 : stayAmountPerNight);
    final int surcharge = enabled ? unit : 0;
    final int campaign = enabled && allowCampaignDiscount
        ? sampleCampaignDiscount
        : 0;
    final int payable = base + surcharge - campaign;

    final String heading = useDaycare ? '安親訂單示意' : '住宿訂單示意';
    final List<DiscountPromoPreviewLine> lines = <DiscountPromoPreviewLine>[
      DiscountPromoPreviewLine(
        label: useDaycare
            ? '安親 1 場 ${nt(base)}'
            : '住宿 $sampleStayNights 晚 ${nt(base)}',
        amount: base,
      ),
    ];

    if (!enabled) {
      lines.add(
        const DiscountPromoPreviewLine(
          label: '規則尚未啟用，不會影響新訂單金額。',
          amount: 0,
          kind: DiscountPromoPreviewKind.hint,
        ),
      );
    } else {
      lines.add(
        DiscountPromoPreviewLine(
          label: useDaycare
              ? '特殊日期加價（每次）+${nt(surcharge)}'
              : '特殊日期加價 +${nt(surcharge)}',
          amount: surcharge,
          kind: DiscountPromoPreviewKind.surcharge,
        ),
      );
      if (allowCampaignDiscount) {
        lines.add(
          DiscountPromoPreviewLine(
            label: '滿額優惠 -${nt(campaign)}',
            amount: -campaign,
            kind: DiscountPromoPreviewKind.discount,
            chip: '示意：可與自動優惠併用',
          ),
        );
      } else {
        lines.add(
          const DiscountPromoPreviewLine(
            label: '此特殊日期規則不與自動優惠併用',
            amount: 0,
            kind: DiscountPromoPreviewKind.hint,
          ),
        );
      }
      if (allowCoupon) {
        lines.add(
          const DiscountPromoPreviewLine(
            label: '會員若持有符合資格的優惠券，可於預約時使用',
            amount: 0,
            kind: DiscountPromoPreviewKind.hint,
          ),
        );
      } else {
        lines.add(
          const DiscountPromoPreviewLine(
            label: '此特殊日期規則不接受優惠券',
            amount: 0,
            kind: DiscountPromoPreviewKind.hint,
          ),
        );
      }
    }

    lines.add(
      DiscountPromoPreviewLine(
        label: '預估應付金額 ${nt(payable)}',
        amount: payable,
        kind: DiscountPromoPreviewKind.total,
      ),
    );

    return DiscountPromoPreviewResult(
      heading: heading,
      lines: lines,
      badges: <String>[if (stay && daycare) (useDaycare ? '安親示意' : '住宿示意')],
    );
  }

  static bool campaignFormReady(DiscountCampaignModel campaign) {
    if (campaign.discountValue <= 0) {
      return false;
    }
    if (campaign.isPercent && campaign.discountValue >= 100) {
      return false;
    }
    switch (campaign.type) {
      case DiscountCampaignType.longStay:
        return campaign.minimumNights > 0;
      case DiscountCampaignType.minimumAmount:
        return campaign.minimumAmount > 0;
      case DiscountCampaignType.stayDate:
      case DiscountCampaignType.limitedTime:
        return campaign.startAt != null && campaign.endAt != null;
      case DiscountCampaignType.roomType:
        return campaign.roomTypeIds.isNotEmpty;
      case DiscountCampaignType.newMember:
        if (campaign.appliesToAccommodation &&
            campaign.newMemberDiscountNights <= 0) {
          return false;
        }
        return true;
      case DiscountCampaignType.googleReview:
        return true;
    }
  }

  static DiscountPromoPreviewResult forCampaignResult({
    required DiscountCampaignModel campaign,
    bool previewDaycare = false,
  }) {
    final bool daycare =
        campaign.appliesToDaycare &&
        (previewDaycare || !campaign.appliesToAccommodation);
    final bool ready = campaignFormReady(campaign);
    final String heading = daycare ? '安親訂單示意' : '住宿訂單示意';
    if (!campaign.enabled) {
      final int base = daycare ? sampleDaycareBase : sampleStayBase;
      return DiscountPromoPreviewResult(
        heading: heading,
        lines: <DiscountPromoPreviewLine>[
          DiscountPromoPreviewLine(
            label: daycare
                ? '安親 1 場 ${nt(base)}'
                : '住宿 $sampleStayNights 晚 ${nt(base)}',
            amount: base,
          ),
          const DiscountPromoPreviewLine(
            label: '活動尚未啟用，新訂單不會套用此優惠。',
            amount: 0,
            kind: DiscountPromoPreviewKind.hint,
          ),
          DiscountPromoPreviewLine(
            label: '預估應付金額 ${nt(base)}',
            amount: base,
            kind: DiscountPromoPreviewKind.total,
          ),
        ],
      );
    }
    if (!ready) {
      return DiscountPromoPreviewResult(
        heading: heading,
        lines: const <DiscountPromoPreviewLine>[
          DiscountPromoPreviewLine(
            label: '完成優惠內容後，這裡會顯示客戶費用示意。',
            amount: 0,
            kind: DiscountPromoPreviewKind.hint,
          ),
        ],
      );
    }

    DateTime checkIn = campaign.startAt ?? DateTime(2026, 9, 28);
    if (campaign.type == DiscountCampaignType.stayDate &&
        campaign.startAt != null) {
      checkIn = DateTime(
        campaign.startAt!.year,
        campaign.startAt!.month,
        campaign.startAt!.day,
      );
    }
    int nights = daycare ? 1 : sampleStayNights;
    if (!daycare && campaign.minimumNights > nights) {
      nights = campaign.minimumNights;
    }
    int roomAmount = daycare ? sampleDaycareBase : sampleStayBase;
    if (!daycare && nights != sampleStayNights) {
      roomAmount = ((sampleStayBase / sampleStayNights) * nights).round();
    }
    if (campaign.minimumAmount > roomAmount) {
      roomAmount = campaign.minimumAmount;
    }
    final DiscountCampaignCalculationInput input =
        DiscountCampaignCalculationInput(
          checkInDate: checkIn,
          checkOutDate: checkIn.add(Duration(days: nights)),
          roomTypeId: campaign.roomTypeIds.isEmpty
              ? 'preview-room'
              : campaign.roomTypeIds.first,
          roomAmount: roomAmount,
          petAmount: 0,
          extraServiceAmount: 0,
          isFirstBooking: true,
          memberJoinedAt: checkIn,
          hasVerifiedGoogleReview: true,
          serviceType: daycare
              ? PolicyApplicableService.daycare
              : PolicyApplicableService.accommodation,
        );
    final DiscountCampaignCalculationResult? result =
        DiscountCampaignCalculator.calculateCampaign(
          campaign: campaign.copyWith(enabled: true),
          input: input,
          now: campaign.startAt ?? checkIn,
        );
    final int discount = result?.discountAmount ?? 0;
    final List<DiscountPromoPreviewLine> lines = <DiscountPromoPreviewLine>[
      DiscountPromoPreviewLine(
        label: daycare
            ? '安親 1 場 ${nt(roomAmount)}'
            : '住宿 $nights 晚 ${nt(roomAmount)}',
        amount: roomAmount,
      ),
    ];
    if (discount <= 0) {
      lines.add(
        const DiscountPromoPreviewLine(
          label: '目前條件下示意訂單尚未符合折抵資格。',
          amount: 0,
          kind: DiscountPromoPreviewKind.hint,
        ),
      );
    } else {
      lines.add(
        DiscountPromoPreviewLine(
          label: '${campaign.name} -${nt(discount)}',
          amount: -discount,
          kind: DiscountPromoPreviewKind.discount,
        ),
      );
    }
    lines.add(
      DiscountPromoPreviewLine(
        label: '預估應付金額 ${nt(roomAmount - discount)}',
        amount: roomAmount - discount,
        kind: DiscountPromoPreviewKind.total,
      ),
    );
    return DiscountPromoPreviewResult(
      heading: heading,
      lines: lines,
      badges: <String>[
        if (campaign.appliesToAccommodation && campaign.appliesToDaycare)
          (daycare ? '安親示意' : '住宿示意'),
      ],
    );
  }

  static List<DiscountPromoPreviewLine> forCampaign(
    DiscountCampaignModel campaign, {
    bool previewDaycare = false,
  }) {
    return forCampaignResult(
      campaign: campaign,
      previewDaycare: previewDaycare,
    ).lines;
  }

  static String campaignBenefit(DiscountCampaignModel campaign) {
    return DiscountCampaignCustomerCopy.benefitLine(campaign);
  }
}
