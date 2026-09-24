// 檔案名稱：test/discount_campaign_customer_copy_test.dart
// 功能說明：客戶端優惠文案與公開活動過濾，沿用既有計算器期間／額度判斷。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/services/discount_campaign_calculator.dart';
import 'package:petnest_saas/core/services/discount_campaign_customer_copy.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 23, 12);

  DiscountCampaignModel campaign({
    String id = 'c1',
    String name = '滿額優惠',
    DiscountCampaignType type = DiscountCampaignType.minimumAmount,
    DiscountValueType valueType = DiscountValueType.percent,
    num discountValue = 10,
    bool enabled = true,
    int usedCount = 0,
    int totalUsageLimit = 0,
    int minimumAmount = 9000,
    DateTime? startAt,
    DateTime? endAt,
    DiscountApplyTarget applyTarget = DiscountApplyTarget.room,
    NewMemberEligibilityMode newMemberEligibilityMode =
        NewMemberEligibilityMode.noPreviousBooking,
  }) {
    return DiscountCampaignModel(
      id: id,
      shopId: 's1',
      name: name,
      type: type,
      valueType: valueType,
      applyTarget: applyTarget,
      discountValue: discountValue,
      enabled: enabled,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      minimumAmount: minimumAmount,
      usedCount: usedCount,
      totalUsageLimit: totalUsageLimit,
      startAt: startAt,
      endAt: endAt,
      newMemberEligibilityMode: newMemberEligibilityMode,
    );
  }

  test('滿額百分比顯示消費滿額與折數，不含後台用語', () {
    final DiscountCampaignModel item = campaign();
    expect(
      DiscountCampaignCustomerCopy.benefitLine(item),
      '消費滿 NT\$9,000 享 9 折',
    );
    expect(
      DiscountCampaignCustomerCopy.restrictionChips(item),
      contains('僅限房價'),
    );
    expect(
      DiscountCampaignCustomerCopy.restrictionChips(item).join(),
      isNot(contains('目前啟用中')),
    );
  });

  test('過期、停用、額滿活動不可公開列出', () {
    expect(
      DiscountCampaignCalculator.isCampaignCurrentlyActive(
        campaign(enabled: false),
        now: now,
      ),
      isFalse,
    );
    expect(
      DiscountCampaignCalculator.isCampaignCurrentlyActive(
        campaign(
          type: DiscountCampaignType.limitedTime,
          endAt: DateTime(2026, 9, 1),
        ),
        now: now,
      ),
      isFalse,
    );
    expect(
      DiscountCampaignCalculator.isCampaignCurrentlyActive(
        campaign(totalUsageLimit: 10, usedCount: 10),
        now: now,
      ),
      isFalse,
    );
    expect(
      DiscountCampaignCalculator.isCampaignCurrentlyActive(
        campaign(
          type: DiscountCampaignType.stayDate,
          endAt: DateTime(2026, 9, 20),
        ),
        now: now,
      ),
      isFalse,
    );
    expect(
      DiscountCampaignCalculator.isCampaignCurrentlyActive(
        campaign(
          type: DiscountCampaignType.limitedTime,
          startAt: DateTime(2026, 9, 1),
          endAt: DateTime(2026, 10, 1),
        ),
        now: now,
      ),
      isTrue,
    );
  });

  test('新會員：未登入可看規則，已登入且非新會員不可寫成可使用', () {
    final DiscountCampaignModel item = campaign(
      type: DiscountCampaignType.newMember,
      valueType: DiscountValueType.fixedAmount,
      discountValue: 500,
    );
    expect(
      DiscountCampaignCalculator.isNewMemberEligibleForDisplay(
        campaign: item,
        isLoggedIn: false,
      ),
      isTrue,
    );
    expect(
      DiscountCampaignCalculator.isNewMemberEligibleForDisplay(
        campaign: item,
        isLoggedIn: true,
        isFirstBooking: false,
      ),
      isFalse,
    );
    expect(DiscountCampaignCustomerCopy.benefitLine(item), '新會員現折 NT\$500');
  });
}
