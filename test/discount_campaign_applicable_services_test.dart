// 檔案名稱：test/discount_campaign_applicable_services_test.dart
// 功能說明：自動優惠適用服務與安親計價，舊資料僅住宿。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/models/policy_applicable_service.dart';
import 'package:petnest_saas/core/services/discount_campaign_calculator.dart';
import 'package:petnest_saas/core/services/discount_campaign_customer_copy.dart';

DiscountCampaignModel campaign({
  DiscountCampaignType type = DiscountCampaignType.minimumAmount,
  List<String>? applicableServices,
  int minimumAmount = 1000,
  int minimumNights = 3,
  num discountValue = 10,
  DiscountValueType valueType = DiscountValueType.percent,
  List<String> roomTypeIds = const <String>[],
  int newMemberDiscountNights = 3,
}) {
  return DiscountCampaignModel(
    id: 'c1',
    shopId: 's1',
    name: '測試活動',
    type: type,
    valueType: valueType,
    applyTarget: DiscountApplyTarget.total,
    discountValue: discountValue,
    enabled: true,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    minimumAmount: minimumAmount,
    minimumNights: minimumNights,
    roomTypeIds: roomTypeIds,
    applicableServices:
        applicableServices ?? PolicyApplicableService.accommodationOnly,
    newMemberDiscountNights: newMemberDiscountNights,
    newMemberEligibilityMode: NewMemberEligibilityMode.noPreviousBooking,
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 9, 30, 23, 59),
    dateMatchType: DiscountDateMatchType.matchingStayDates,
  );
}

DiscountCampaignCalculationInput input({
  String serviceType = PolicyApplicableService.accommodation,
  int roomAmount = 3000,
  String roomTypeId = 'room-a',
  bool isFirstBooking = true,
}) {
  final DateTime checkIn = DateTime(2026, 9, 28);
  return DiscountCampaignCalculationInput(
    checkInDate: checkIn,
    checkOutDate: checkIn.add(const Duration(days: 1)),
    roomTypeId: roomTypeId,
    roomAmount: roomAmount,
    petAmount: 0,
    extraServiceAmount: 0,
    isFirstBooking: isFirstBooking,
    memberJoinedAt: DateTime(2026, 2, 1),
    serviceType: serviceType,
  );
}

void main() {
  test('舊活動沒有 applicableServices 時僅住宿', () {
    final DiscountCampaignModel item = DiscountCampaignModel.fromMap(
      id: 'legacy',
      data: <String, dynamic>{
        'shopId': 's1',
        'name': '舊活動',
        'type': 'minimumAmount',
        'valueType': 'percent',
        'applyTarget': 'total',
        'discountValue': 10,
        'enabled': true,
        'minimumAmount': 1000,
        'createdAt': DateTime(2026, 1, 1),
        'updatedAt': DateTime(2026, 1, 1),
      },
    );
    expect(item.applicableServices, PolicyApplicableService.accommodationOnly);
    expect(
      DiscountCampaignCalculator.calculateCampaign(
        campaign: item,
        input: input(serviceType: PolicyApplicableService.daycare),
        now: DateTime(2026, 9, 10),
      ),
      isNull,
    );
    expect(
      DiscountCampaignCalculator.ineligibilityReason(
        campaign: item,
        input: input(serviceType: PolicyApplicableService.daycare),
        now: DateTime(2026, 9, 10),
      ),
      '此優惠僅適用住宿',
    );
  });

  test('滿額優惠可套用安親', () {
    final DiscountCampaignModel item = campaign(
      applicableServices: PolicyApplicableService.shared,
    );
    final DiscountCampaignCalculationResult? result =
        DiscountCampaignCalculator.calculateCampaign(
          campaign: item,
          input: input(serviceType: PolicyApplicableService.daycare),
          now: DateTime(2026, 9, 10),
        );
    expect(result, isNotNull);
    expect(result!.discountAmount, 300);
  });

  test('長住優惠不可套用安親', () {
    final DiscountCampaignModel item = campaign(
      type: DiscountCampaignType.longStay,
      applicableServices: PolicyApplicableService.shared,
    );
    expect(
      DiscountCampaignCalculator.calculateCampaign(
        campaign: item,
        input: input(serviceType: PolicyApplicableService.daycare),
        now: DateTime(2026, 9, 10),
      ),
      isNull,
    );
    expect(
      DiscountCampaignCalculator.ineligibilityReason(
        campaign: item,
        input: input(serviceType: PolicyApplicableService.daycare),
        now: DateTime(2026, 9, 10),
      ),
      '長住優惠僅適用住宿',
    );
  });

  test('新會員安親使用百分比，不消耗住宿晚數', () {
    final DiscountCampaignModel item = campaign(
      type: DiscountCampaignType.newMember,
      applicableServices: PolicyApplicableService.daycareOnly,
      newMemberDiscountNights: 0,
    );
    final DiscountCampaignCalculationResult? result =
        DiscountCampaignCalculator.calculateCampaign(
          campaign: item,
          input: input(serviceType: PolicyApplicableService.daycare),
          now: DateTime(2026, 9, 10),
        );
    expect(result, isNotNull);
    expect(result!.discountUsedNights, 0);
    expect(result.discountAmount, 300);
  });

  test('指定房型安親未對應方案 ID 時不套用', () {
    final DiscountCampaignModel item = campaign(
      type: DiscountCampaignType.roomType,
      applicableServices: PolicyApplicableService.daycareOnly,
      roomTypeIds: <String>['stay-room'],
    );
    expect(
      DiscountCampaignCalculator.calculateCampaign(
        campaign: item,
        input: input(
          serviceType: PolicyApplicableService.daycare,
          roomTypeId: 'plan-1',
        ),
        now: DateTime(2026, 9, 10),
      ),
      isNull,
    );
  });

  test('指定服務日期文案', () {
    expect(
      DiscountCampaignCustomerCopy.benefitLine(
        campaign(type: DiscountCampaignType.stayDate),
      ),
      contains('指定服務日期'),
    );
  });
}
