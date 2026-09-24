// 檔案名稱：lib/core/services/discount_campaign_customer_copy.dart
// 功能說明：把既有優惠活動資料轉成客戶聽得懂的名稱、優惠與限制摘要。

import '../models/discount_campaign_model.dart';
import 'shop_report_format.dart';

class DiscountCampaignCustomerCopy {
  DiscountCampaignCustomerCopy._();

  static String money(int amount) => 'NT\$${ShopReportFormat.number(amount)}';

  static String percentOffLabel(num discountValue) {
    final num payPercent = 100 - discountValue;
    if (payPercent % 10 == 0) {
      return '${(payPercent / 10).toStringAsFixed(0)} 折';
    }
    return '${(payPercent / 10).toStringAsFixed(1)} 折';
  }

  static String valuePhrase(DiscountCampaignModel campaign) {
    if (campaign.isPercent) {
      return percentOffLabel(campaign.discountValue);
    }
    return '現折 ${money(campaign.discountValue.round())}';
  }

  static String benefitLine(DiscountCampaignModel campaign) {
    final String off = valuePhrase(campaign);
    switch (campaign.type) {
      case DiscountCampaignType.minimumAmount:
        return '消費滿 ${money(campaign.minimumAmount)} 享 $off';
      case DiscountCampaignType.roomType:
        return '指定房型享 $off';
      case DiscountCampaignType.newMember:
        return campaign.isFixedAmount ? '新會員$off' : '新會員享 $off';
      case DiscountCampaignType.longStay:
        return '入住滿 ${campaign.minimumNights} 晚享 $off';
      case DiscountCampaignType.stayDate:
        return '指定服務日期享 $off';
      case DiscountCampaignType.limitedTime:
        return '限時優惠 $off';
      case DiscountCampaignType.googleReview:
        return '完成評論享 $off';
    }
  }

  static String applyTargetLabel(DiscountApplyTarget target) {
    switch (target) {
      case DiscountApplyTarget.room:
        return '僅限房價';
      case DiscountApplyTarget.roomAndPet:
        return '僅限房價與寵物費';
      case DiscountApplyTarget.total:
        return '可折整張訂單';
    }
  }

  static String periodEndLabel(DateTime endAt) {
    final String month = endAt.month.toString().padLeft(2, '0');
    final String day = endAt.day.toString().padLeft(2, '0');
    return '活動期間至 $month/$day';
  }

  static List<String> restrictionChips(DiscountCampaignModel campaign) {
    final List<String> chips = <String>[applyTargetLabel(campaign.applyTarget)];
    if (campaign.type == DiscountCampaignType.newMember) {
      chips.add('新會員限定');
    }
    if (campaign.hasRoomTypeLimit) {
      chips.add('指定房型');
    }
    if (campaign.type != DiscountCampaignType.newMember &&
        campaign.memberUsageLimit == 1) {
      chips.add('每位會員限用一次');
    } else if (campaign.type != DiscountCampaignType.newMember &&
        campaign.memberUsageLimit > 1) {
      chips.add('每位會員限用 ${campaign.memberUsageLimit} 次');
    }
    if (campaign.minimumNights > 0 &&
        campaign.type != DiscountCampaignType.longStay) {
      chips.add('入住滿 ${campaign.minimumNights} 晚');
    }
    if (campaign.endAt != null &&
        campaign.type != DiscountCampaignType.stayDate) {
      chips.add(periodEndLabel(campaign.endAt!));
    }
    if (campaign.type == DiscountCampaignType.stayDate &&
        campaign.endAt != null) {
      chips.add(periodEndLabel(campaign.endAt!));
    }
    return chips;
  }
}
