// 檔案名稱：lib/features/shop/widgets/booking/booking_campaign_ui.dart
// 功能說明：前台住宿預約的符合優惠卡片與活動詳情 BottomSheet。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class BookingCurrentCampaignCard extends StatelessWidget {
  const BookingCurrentCampaignCard({
    super.key,
    required this.theme,
    required this.discountInfo,
    required this.campaign,
    required this.onShowDetail,
  });

  final HomeThemeModel theme;
  final Map<String, dynamic> discountInfo;
  final DiscountCampaignModel? campaign;
  final ValueChanged<DiscountCampaignModel> onShowDetail;

  static String formatDiscountNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String formatDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final bool campaignBlockedBySpecialDate =
        (discountInfo['campaignBlockedBySpecialDate'] ?? false) == true;
    if (campaignBlockedBySpecialDate) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, color: Colors.orange.shade800, size: 21),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '目前住宿日期包含特殊日期加價，本次不適用自動優惠活動。',
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final String campaignId = (discountInfo['discountCampaignId'] ?? '')
        .toString()
        .trim();
    final String campaignName = (discountInfo['discountCampaignName'] ?? '')
        .toString()
        .trim();
    final int discountAmount = ((discountInfo['discountAmount'] ?? 0) as num)
        .toInt();
    if (campaignId.isEmpty || campaignName.isEmpty || discountAmount <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF43A85B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.card_giftcard_outlined,
                color: Color(0xFF2E8B47),
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '目前符合優惠',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '預估 -NT\$ $discountAmount',
                style: const TextStyle(
                  color: Color(0xFF2E8B47),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle,
                color: Color(0xFF2E8B47),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  campaignName,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (campaign != null)
                IconButton(
                  tooltip: '查看活動詳情',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  onPressed: () => onShowDetail(campaign!),
                  icon: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF2E8B47),
                    size: 21,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showBookingCampaignDetailSheet({
  required BuildContext context,
  required DiscountCampaignModel campaign,
}) {
  String applyTargetText;
  switch (campaign.applyTarget) {
    case DiscountApplyTarget.room:
      applyTargetText = '只折房價';
    case DiscountApplyTarget.roomAndPet:
      applyTargetText = '折房價＋寵物費';
    case DiscountApplyTarget.total:
      applyTargetText = '折訂單總金額';
  }

  final String discountValueText =
      campaign.valueType == DiscountValueType.percent
      ? '${BookingCurrentCampaignCard.formatDiscountNumber(campaign.discountValue)}% 折抵'
      : '固定折抵 NT\$${BookingCurrentCampaignCard.formatDiscountNumber(campaign.discountValue)}';

  final String campaignPeriodText;
  if (campaign.startAt == null && campaign.endAt == null) {
    campaignPeriodText = '未限制活動期間';
  } else {
    final String startText = campaign.startAt == null
        ? '未設定開始日'
        : BookingCurrentCampaignCard.formatDate(campaign.startAt!);
    final String endText = campaign.endAt == null
        ? '未設定結束日'
        : BookingCurrentCampaignCard.formatDate(campaign.endAt!);
    campaignPeriodText = '$startText ～ $endText';
  }

  Widget detailRow({required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext bottomSheetContext) {
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.card_giftcard_outlined,
                      color: Color(0xFF2E8B47),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        campaign.name,
                        style: Theme.of(bottomSheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF8EE),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF43A85B)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                '活動說明',
                                style: TextStyle(
                                  color: Color(0xFF2E8B47),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                campaign.description.trim().isEmpty
                                    ? '店家目前沒有填寫其他活動說明。'
                                    : campaign.description.trim(),
                                style: const TextStyle(height: 1.6),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        detailRow(title: '活動期間', value: campaignPeriodText),
                        detailRow(title: '折扣範圍', value: applyTargetText),
                        detailRow(title: '折扣內容', value: discountValueText),
                        detailRow(
                          title: '最高折抵',
                          value: campaign.maximumDiscountAmount > 0
                              ? 'NT\$${campaign.maximumDiscountAmount}'
                              : '未限制最高折抵金額',
                        ),
                        detailRow(
                          title: '最低晚數',
                          value: campaign.minimumNights > 0
                              ? '${campaign.minimumNights} 晚'
                              : '不限住宿晚數',
                        ),
                        detailRow(
                          title: '最低消費',
                          value: campaign.minimumAmount > 0
                              ? 'NT\$${campaign.minimumAmount}'
                              : '無最低消費限制',
                        ),
                        detailRow(
                          title: '適用房型',
                          value: campaign.roomTypeIds.isEmpty
                              ? '所有房型'
                              : '限指定房型，共 ${campaign.roomTypeIds.length} 種',
                        ),
                        detailRow(
                          title: '會員限制',
                          value: campaign.type == DiscountCampaignType.newMember
                              ? campaign.newMemberEligibilityMode ==
                                        NewMemberEligibilityMode
                                            .createdAfterCampaign
                                    ? '活動建立後加入的新會員'
                                    : '本店尚未有有效訂單的會員'
                              : '依活動設定判斷',
                        ),
                        detailRow(
                          title: '優惠券',
                          value: campaign.allowCouponTogether
                              ? '可與會員優惠券一起使用'
                              : '不可與會員優惠券一起使用',
                        ),
                        if (campaign.type == DiscountCampaignType.newMember)
                          detailRow(
                            title: '優惠額度',
                            value: campaign.newMemberDiscountNights > 0
                                ? '共 ${campaign.newMemberDiscountNights} 晚，可分次使用'
                                : '依活動設定',
                          )
                        else if (campaign.memberUsageLimit > 0)
                          detailRow(
                            title: '使用次數',
                            value: '每位會員最多使用 ${campaign.memberUsageLimit} 次',
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '實際折扣仍會依最終日期、房型、加值服務、會員資格及訂單金額重新計算。',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    child: const Text('關閉'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
