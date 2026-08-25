// lib/features/shop/widgets/booking/booking_summary_helper.dart
// 🔥 前台預約確認 helper
// 功能：計算房價、寵物加價、一般加購、客製化服務、每日分時段服務，
// 並建立預約金額 Summary Card。

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_card.dart';

class BookingSummaryHelper {
  /// ===============================
  /// 🔥 拆分計算各項價格
  /// ===============================
  static Map<String, int> calculatePriceParts({
    required Map<String, dynamic> selectedRoomType,
    required int nights,
    required List<String> selectedPetIds,
    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,

    /// 每日分時段服務：
    /// serviceId → petId → yyyy-MM-dd → 時段 ID 清單
    Map<String, Map<String, Map<String, List<String>>>>
        selectedDailyTimedServices =
        const {},

    required Map<String, dynamic>? addonData,
  }) {
    final basePrice = ((selectedRoomType['price'] ?? 0) as num).toInt();
    final extraPrice = ((selectedRoomType['extraPrice'] ?? 0) as num).toInt();

    /// 房間住宿費
    final roomTotal = basePrice * nights;

    /// 多寵物加價
    final petCount = selectedPetIds.length;
    final extraCount = petCount > 1 ? petCount - 1 : 0;
    final petTotal = extraCount * extraPrice * nights;

    int addonTotal = 0;

    /// 營業時間外入住
    if (selectedTimeAddon != null) {
      addonTotal += ((selectedTimeAddon['price'] ?? 0) as num).toInt();
    }

    /// 一般加值服務
    for (final item in selectedValueServices) {
      addonTotal += ((item['price'] ?? 0) as num).toInt();
    }

    /// 客製化服務
    for (final entry in selectedCustomServices.entries) {
      final serviceName = entry.key;
      final selectedPets = entry.value;

      final customServices = List<Map<String, dynamic>>.from(
        addonData?['customServices'] ?? [],
      );

      final service = customServices.firstWhere(
        (item) => item['name']?.toString() == serviceName,
        orElse: () => <String, dynamic>{},
      );

      final price = ((service['price'] ?? 0) as num).toInt();

      addonTotal += price * selectedPets.length;
    }

    /// 每日分時段服務
    ///
    /// 計算方式：
    /// 每個寵物選擇的日期 × 時段數量 × 該服務單價
    final dailyTimedServices = List<Map<String, dynamic>>.from(
      addonData?['dailyTimedServices'] ?? [],
    );

    for (final entry in dailyTimedServices.asMap().entries) {
      final serviceIndex = entry.key;
      final service = entry.value;

      final rawServiceId = service['id']?.toString().trim() ?? '';
      final serviceName = service['name']?.toString().trim() ?? '';

      final serviceId = rawServiceId.isNotEmpty
          ? rawServiceId
          : serviceName.isNotEmpty
          ? 'daily_timed_$serviceName'
          : 'daily_timed_$serviceIndex';

      final serviceSelections = selectedDailyTimedServices[serviceId];

      if (serviceSelections == null || serviceSelections.isEmpty) {
        continue;
      }

      final servicePrice = ((service['price'] ?? 0) as num).toInt();

      int selectedCount = 0;

      /// petId → 日期資料
      for (final petSelections in serviceSelections.values) {
        /// yyyy-MM-dd → 時段 ID 清單
        for (final selectedSlotIds in petSelections.values) {
          selectedCount += selectedSlotIds.length;
        }
      }

      addonTotal += selectedCount * servicePrice;
    }

    return {
      'roomTotal': roomTotal,
      'petTotal': petTotal,
      'addonTotal': addonTotal,
      'subtotal': roomTotal + petTotal + addonTotal,
    };
  }

  /// ===============================
  /// 🔥 計算總價
  /// ===============================
  static int calculateTotalPrice({
    required Map<String, dynamic> selectedRoomType,
    required int nights,
    required List<String> selectedPetIds,
    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,

    /// 每日分時段服務選擇結果
    Map<String, Map<String, Map<String, List<String>>>>
        selectedDailyTimedServices =
        const {},

    required Map<String, dynamic>? addonData,
  }) {
    final parts = calculatePriceParts(
      selectedRoomType: selectedRoomType,
      nights: nights,
      selectedPetIds: selectedPetIds,
      selectedTimeAddon: selectedTimeAddon,
      selectedValueServices: selectedValueServices,
      selectedCustomServices: selectedCustomServices,
      selectedDailyTimedServices: selectedDailyTimedServices,
      addonData: addonData,
    );

    return parts['subtotal'] ?? 0;
  }

  /// ===============================
  /// 🔥 建立 Summary Card
  /// ===============================
  static Widget buildSummary({
    required String startDateText,
    required String endDateText,
    required int nights,
    required List<String> selectedPetIds,
    required List<Map<String, dynamic>> pets,
    required Map<String, dynamic> selectedRoomType,
    required int totalPrice,
    int depositAmount = 0,
    int? originalTotal,
    int discountAmount = 0,
    int discountPercent = 0,
    int discountMinNights = 0,
    String discountBase = '',
    String discountCampaignName = '',
    String discountValueType = '',
    num discountValue = 0,
    String discountCampaignType = '',
    int discountUsedNights = 0,
    int remainingDiscountNights = 0,
    int specialDateSurchargeAmount = 0,
    List<Map<String, dynamic>> specialDateSurchargeDetails = const [],
    String couponName = '',
    int couponDiscountAmount = 0,

    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,

    /// 每日分時段服務：
    /// serviceId → petId → yyyy-MM-dd → 時段 ID 清單
    required Map<String, Map<String, Map<String, List<String>>>>
    selectedDailyTimedServices,

    required Map<String, dynamic>? addonData,
  }) {
    final petNamesById = <String, String>{};

    for (final pet in pets) {
      final petId =
          pet['petId']?.toString().trim() ?? pet['id']?.toString().trim() ?? '';

      final petName = pet['name']?.toString().trim() ?? '';

      if (petId.isNotEmpty) {
        petNamesById[petId] = petName.isNotEmpty ? petName : petId;
      }
    }
    final Map<String, int> customServicePrices = {};

    final customServices = List<Map<String, dynamic>>.from(
      addonData?['customServices'] ?? [],
    );

    for (final entry in selectedCustomServices.entries) {
      final name = entry.key;

      final service = customServices.firstWhere(
        (item) => item['name']?.toString() == name,
        orElse: () => <String, dynamic>{},
      );

      customServicePrices[name] = ((service['price'] ?? 0) as num).toInt();
    }

    return BookingSummaryCard(
      startDateText: startDateText,
      endDateText: endDateText,
      nights: nights,
      petCount: selectedPetIds.length,
      roomTypeName: selectedRoomType['name'] ?? '',
      totalPrice: totalPrice,
      depositAmount: depositAmount,
      originalTotal: originalTotal,
      discountAmount: discountAmount,
      discountPercent: discountPercent,
      discountMinNights: discountMinNights,
      discountBase: discountBase,
      discountCampaignName: discountCampaignName,
      discountValueType: discountValueType,
      discountValue: discountValue,
      discountCampaignType: discountCampaignType,
      discountUsedNights: discountUsedNights,
      remainingDiscountNights: remainingDiscountNights,
      specialDateSurchargeAmount: specialDateSurchargeAmount,
      specialDateSurchargeDetails: specialDateSurchargeDetails,
      couponName: couponName,
      couponDiscountAmount: couponDiscountAmount,

      timeAddon: selectedTimeAddon,
      valueServices: selectedValueServices,
      customServices: selectedCustomServices,
      customServicePrices: customServicePrices,
      dailyTimedServices: List<Map<String, dynamic>>.from(
        addonData?['dailyTimedServices'] ?? [],
      ),
      selectedDailyTimedServices: selectedDailyTimedServices,
      petNamesById: petNamesById,
    );
  }
}
