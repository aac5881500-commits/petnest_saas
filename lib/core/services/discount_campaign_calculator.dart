// lib/core/services/discount_campaign_calculator.dart
// 🧮 優惠活動計算器
// 功能：判斷訂單符合哪些自動優惠，計算折抵金額，並選出最高優惠

import '../models/discount_campaign_model.dart';

/// 訂單優惠計算所需資料
class DiscountCampaignCalculationInput {
  const DiscountCampaignCalculationInput({
    required this.checkInDate,
    required this.checkOutDate,
    required this.roomTypeId,
    required this.roomAmount,
    required this.petAmount,
    required this.extraServiceAmount,
    this.isFirstBooking = false,
    this.hasVerifiedGoogleReview = false,
    this.memberCampaignUsage = const <String, int>{},
    this.memberCampaignUsedNights = const <String, int>{},
  });

  /// 入住日
  final DateTime checkInDate;

  /// 退房日
  final DateTime checkOutDate;

  /// 本次選擇的房型 ID
  final String roomTypeId;

  /// 房價總額
  final num roomAmount;

  /// 寵物加價總額
  final num petAmount;

  /// 加值服務總額
  final num extraServiceAmount;

  /// 是否為該會員在此店的第一次有效預約
  final bool isFirstBooking;

  /// 是否已完成並通過 Google 評論驗證
  ///
  /// 目前尚未接驗證流程，前台接線時先傳 false。
  final bool hasVerifiedGoogleReview;

  /// 該會員對各活動已使用的次數
  ///
  /// key：campaignId
  /// value：已使用次數
  final Map<String, int> memberCampaignUsage;

  /// 該會員對各活動已使用的優惠晚數
  ///
  /// 主要提供新會員優惠使用。
  ///
  /// key：campaignId
  /// value：該活動過去已使用的優惠晚數
  final Map<String, int> memberCampaignUsedNights;

  int get nights {
    final DateTime start = _dateOnly(checkInDate);
    final DateTime end = _dateOnly(checkOutDate);
    final int difference = end.difference(start).inDays;

    return difference < 0 ? 0 : difference;
  }

  num get totalAmount {
    return roomAmount + petAmount + extraServiceAmount;
  }

  int usedNightsForCampaign(String campaignId) {
    final int usedNights = memberCampaignUsedNights[campaignId] ?? 0;

    return usedNights < 0 ? 0 : usedNights;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

/// 單一優惠的計算結果
class DiscountCampaignCalculationResult {
  const DiscountCampaignCalculationResult({
    required this.campaign,
    required this.discountAmount,
    required this.discountBaseAmount,
    this.discountUsedNights = 0,
  });

  final DiscountCampaignModel campaign;

  /// 實際折抵金額
  final int discountAmount;

  /// 此優惠拿來計算折扣的基礎金額
  final num discountBaseAmount;

  /// 本次訂單實際使用的優惠晚數
  ///
  /// 目前主要用於新會員優惠。
  /// 其他優惠類型預設為 0。
  final int discountUsedNights;

  int get finalAmountBeforeCoupon {
    final int originalAmount = discountBaseAmount.round();
    final int result = originalAmount - discountAmount;

    return result < 0 ? 0 : result;
  }
}

class DiscountCampaignCalculator {
  const DiscountCampaignCalculator._();

  /// 計算指定新會員活動目前剩餘的優惠晚數
  static int remainingNewMemberDiscountNights({
    required DiscountCampaignModel campaign,
    required DiscountCampaignCalculationInput input,
  }) {
    if (campaign.type != DiscountCampaignType.newMember) {
      return 0;
    }

    final int totalDiscountNights = campaign.newMemberDiscountNights;

    if (totalDiscountNights <= 0) {
      return 0;
    }

    final int usedNights = input.usedNightsForCampaign(campaign.id);
    final int remainingNights = totalDiscountNights - usedNights;

    return remainingNights < 0 ? 0 : remainingNights;
  }

  /// 從所有優惠中選出折抵金額最高的一個
  static DiscountCampaignCalculationResult? findBestCampaign({
    required List<DiscountCampaignModel> campaigns,
    required DiscountCampaignCalculationInput input,
    DateTime? now,
  }) {
    final List<DiscountCampaignCalculationResult> results =
        calculateEligibleCampaigns(
          campaigns: campaigns,
          input: input,
          now: now,
        );

    if (results.isEmpty) {
      return null;
    }

    results.sort((
      DiscountCampaignCalculationResult first,
      DiscountCampaignCalculationResult second,
    ) {
      final int amountCompare = second.discountAmount.compareTo(
        first.discountAmount,
      );

      if (amountCompare != 0) {
        return amountCompare;
      }

      // 折抵金額相同時，優先使用較早建立的活動。
      return first.campaign.createdAt.compareTo(second.campaign.createdAt);
    });

    return results.first;
  }

  /// 計算所有符合條件的優惠
  static List<DiscountCampaignCalculationResult> calculateEligibleCampaigns({
    required List<DiscountCampaignModel> campaigns,
    required DiscountCampaignCalculationInput input,
    DateTime? now,
  }) {
    final DateTime calculationTime = now ?? DateTime.now();

    final List<DiscountCampaignCalculationResult> results =
        <DiscountCampaignCalculationResult>[];

    for (final DiscountCampaignModel campaign in campaigns) {
      final DiscountCampaignCalculationResult? result = calculateCampaign(
        campaign: campaign,
        input: input,
        now: calculationTime,
      );

      if (result != null && result.discountAmount > 0) {
        results.add(result);
      }
    }

    return results;
  }

  /// 計算單一優惠；不符合條件時回傳 null
  static DiscountCampaignCalculationResult? calculateCampaign({
    required DiscountCampaignModel campaign,
    required DiscountCampaignCalculationInput input,
    DateTime? now,
  }) {
    final DateTime calculationTime = now ?? DateTime.now();

    if (!campaign.enabled || campaign.isUsageLimitReached) {
      return null;
    }

    if (!_isWithinCampaignPeriod(campaign, calculationTime)) {
      return null;
    }

    if (!_isMemberUsageAvailable(campaign, input)) {
      return null;
    }

    if (!_matchesCampaignType(campaign, input)) {
      return null;
    }

    int discountUsedNights = 0;

    num discountBaseAmount = _discountBaseAmount(campaign, input);

    if (campaign.type == DiscountCampaignType.newMember) {
      final int remainingNights = remainingNewMemberDiscountNights(
        campaign: campaign,
        input: input,
      );

      discountUsedNights = input.nights < remainingNights
          ? input.nights
          : remainingNights;

      if (discountUsedNights <= 0 || input.nights <= 0) {
        return null;
      }

      final num averageRoomPricePerNight = input.roomAmount / input.nights;

      discountBaseAmount = averageRoomPricePerNight * discountUsedNights;
    }

    if (campaign.type == DiscountCampaignType.stayDate &&
        campaign.dateMatchType == DiscountDateMatchType.matchingStayDates) {
      discountBaseAmount = _matchingStayDateRoomAmount(
        campaign: campaign,
        input: input,
      );
    }

    if (discountBaseAmount <= 0) {
      return null;
    }

    final int discountAmount = _calculateDiscountAmount(
      campaign: campaign,
      discountBaseAmount: discountBaseAmount,
    );

    if (discountAmount <= 0) {
      return null;
    }

    return DiscountCampaignCalculationResult(
      campaign: campaign,
      discountAmount: discountAmount,
      discountBaseAmount: discountBaseAmount,
      discountUsedNights: discountUsedNights,
    );
  }

  static bool _matchesCampaignType(
    DiscountCampaignModel campaign,
    DiscountCampaignCalculationInput input,
  ) {
    switch (campaign.type) {
      case DiscountCampaignType.longStay:
        return campaign.minimumNights > 0 &&
            input.nights >= campaign.minimumNights;

      case DiscountCampaignType.newMember:
        return input.nights > 0 &&
            remainingNewMemberDiscountNights(campaign: campaign, input: input) >
                0;

      case DiscountCampaignType.googleReview:
        return input.hasVerifiedGoogleReview;

      case DiscountCampaignType.stayDate:
        return _matchesStayDate(campaign, input);
      case DiscountCampaignType.roomType:
        final bool matchesRoomType =
            campaign.roomTypeIds.isNotEmpty &&
            campaign.roomTypeIds.contains(input.roomTypeId);

        if (!matchesRoomType) {
          return false;
        }

        if (!campaign.limitStayDate) {
          return true;
        }

        final DateTime? stayStartAt = campaign.stayStartAt;
        final DateTime? stayEndAt = campaign.stayEndAt;

        if (stayStartAt == null || stayEndAt == null) {
          return false;
        }

        final DateTime bookingStartDate = DateTime(
          input.checkInDate.year,
          input.checkInDate.month,
          input.checkInDate.day,
        );

        final DateTime bookingEndDate = DateTime(
          input.checkOutDate.year,
          input.checkOutDate.month,
          input.checkOutDate.day,
        );
        final DateTime campaignStartDate = DateTime(
          stayStartAt.year,
          stayStartAt.month,
          stayStartAt.day,
        );

        final DateTime campaignEndDate = DateTime(
          stayEndAt.year,
          stayEndAt.month,
          stayEndAt.day,
          23,
          59,
          59,
        );

        return !bookingStartDate.isBefore(campaignStartDate) &&
            !bookingEndDate.isAfter(campaignEndDate);
      case DiscountCampaignType.minimumAmount:
        return campaign.minimumAmount > 0 &&
            input.totalAmount >= campaign.minimumAmount;

      case DiscountCampaignType.limitedTime:
        return true;
    }
  }

  static bool _matchesStayDate(
    DiscountCampaignModel campaign,
    DiscountCampaignCalculationInput input,
  ) {
    final DateTime? campaignStart = campaign.startAt == null
        ? null
        : _dateOnly(campaign.startAt!);

    final DateTime? campaignEnd = campaign.endAt == null
        ? null
        : _dateOnly(campaign.endAt!);

    if (campaignStart == null || campaignEnd == null) {
      return false;
    }

    final DateTime checkIn = _dateOnly(input.checkInDate);
    final DateTime checkOut = _dateOnly(input.checkOutDate);

    switch (campaign.dateMatchType ?? DiscountDateMatchType.matchingStayDates) {
      case DiscountDateMatchType.matchingStayDates:
        return checkIn.isBefore(campaignEnd.add(const Duration(days: 1))) &&
            checkOut.isAfter(campaignStart);

      case DiscountDateMatchType.checkInDate:
        return !_isBefore(checkIn, campaignStart) &&
            !_isAfter(checkIn, campaignEnd);

      case DiscountDateMatchType.entireStay:
        final DateTime finalStayDate = checkOut.subtract(
          const Duration(days: 1),
        );

        return !_isBefore(checkIn, campaignStart) &&
            !_isAfter(finalStayDate, campaignEnd);
    }
  }

  static bool _isWithinCampaignPeriod(
    DiscountCampaignModel campaign,
    DateTime now,
  ) {
    if (campaign.type == DiscountCampaignType.stayDate) {
      return true;
    }

    if (campaign.startAt != null && now.isBefore(campaign.startAt!)) {
      return false;
    }

    if (campaign.endAt != null && now.isAfter(campaign.endAt!)) {
      return false;
    }

    return true;
  }

  static bool _isMemberUsageAvailable(
    DiscountCampaignModel campaign,
    DiscountCampaignCalculationInput input,
  ) {
    // 新會員優惠改用「優惠總晚數」限制，
    // 允許會員分多筆訂單使用，不再受使用次數限制阻擋。
    if (campaign.type == DiscountCampaignType.newMember) {
      return remainingNewMemberDiscountNights(
            campaign: campaign,
            input: input,
          ) >
          0;
    }

    if (campaign.memberUsageLimit <= 0) {
      return true;
    }

    final int usedCount = input.memberCampaignUsage[campaign.id] ?? 0;

    return usedCount < campaign.memberUsageLimit;
  }

  static num _discountBaseAmount(
    DiscountCampaignModel campaign,
    DiscountCampaignCalculationInput input,
  ) {
    switch (campaign.applyTarget) {
      case DiscountApplyTarget.room:
        return input.roomAmount;

      case DiscountApplyTarget.roomAndPet:
        return input.roomAmount + input.petAmount;

      case DiscountApplyTarget.total:
        return input.totalAmount;
    }
  }

  static int _calculateDiscountAmount({
    required DiscountCampaignModel campaign,
    required num discountBaseAmount,
  }) {
    num discountAmount;

    switch (campaign.valueType) {
      case DiscountValueType.percent:
        // 表單輸入 15，代表折扣 15%，會員支付原價的 85%。
        discountAmount = discountBaseAmount * campaign.discountValue / 100;

        if (campaign.maximumDiscountAmount > 0 &&
            discountAmount > campaign.maximumDiscountAmount) {
          discountAmount = campaign.maximumDiscountAmount;
        }

      case DiscountValueType.fixedAmount:
        discountAmount = campaign.discountValue;
    }

    if (discountAmount > discountBaseAmount) {
      discountAmount = discountBaseAmount;
    }

    return discountAmount.round();
  }

  static num _matchingStayDateRoomAmount({
    required DiscountCampaignModel campaign,
    required DiscountCampaignCalculationInput input,
  }) {
    final DateTime? campaignStart = campaign.startAt == null
        ? null
        : _dateOnly(campaign.startAt!);

    final DateTime? campaignEnd = campaign.endAt == null
        ? null
        : _dateOnly(campaign.endAt!);

    if (campaignStart == null ||
        campaignEnd == null ||
        input.nights <= 0 ||
        input.roomAmount <= 0) {
      return 0;
    }

    final DateTime checkIn = _dateOnly(input.checkInDate);
    final DateTime checkOut = _dateOnly(input.checkOutDate);

    int matchingNights = 0;

    for (
      DateTime stayDate = checkIn;
      stayDate.isBefore(checkOut);
      stayDate = stayDate.add(const Duration(days: 1))
    ) {
      final bool isWithinRange =
          !_isBefore(stayDate, campaignStart) &&
          !_isAfter(stayDate, campaignEnd);

      if (isWithinRange) {
        matchingNights++;
      }
    }

    if (matchingNights <= 0) {
      return 0;
    }

    final num averageRoomPricePerNight = input.roomAmount / input.nights;

    return averageRoomPricePerNight * matchingNights;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _isBefore(DateTime first, DateTime second) {
    return first.isBefore(second);
  }

  static bool _isAfter(DateTime first, DateTime second) {
    return first.isAfter(second);
  }
}
