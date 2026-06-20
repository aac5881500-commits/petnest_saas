// lib/features/shop/widgets/booking/booking_summary_helper.dart
// 🔥 前台預約確認 helper：負責計算價格與建立 summary card

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_card.dart';

class BookingSummaryHelper {
  static Map<String, int> calculatePriceParts({
    required Map<String, dynamic> selectedRoomType,
    required int nights,
    required List<String> selectedPetIds,
    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,
    required Map<String, dynamic>? addonData,
  }) {
    final basePrice = ((selectedRoomType['price'] ?? 0) as num).toInt();
    final extraPrice = ((selectedRoomType['extraPrice'] ?? 0) as num).toInt();

    final roomTotal = basePrice * nights;

    final petCount = selectedPetIds.length;
    final extraCount = petCount > 1 ? petCount - 1 : 0;
    final petTotal = extraCount * extraPrice * nights;

    int addonTotal = 0;

    if (selectedTimeAddon != null) {
      addonTotal += ((selectedTimeAddon['price'] ?? 0) as num).toInt();
    }

    for (final item in selectedValueServices) {
      addonTotal += ((item['price'] ?? 0) as num).toInt();
    }

    for (final entry in selectedCustomServices.entries) {
      final serviceName = entry.key;
      final selectedPets = entry.value;

      final service = (addonData?['customServices'] ?? []).firstWhere(
        (e) => e['name'] == serviceName,
        orElse: () => {},
      );

      final price = ((service['price'] ?? 0) as num).toInt();

      addonTotal += price * selectedPets.length;
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
    required Map<String, dynamic>? addonData,
  }) {
    final parts = calculatePriceParts(
      selectedRoomType: selectedRoomType,
      nights: nights,
      selectedPetIds: selectedPetIds,
      selectedTimeAddon: selectedTimeAddon,
      selectedValueServices: selectedValueServices,
      selectedCustomServices: selectedCustomServices,
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
    required Map<String, dynamic> selectedRoomType,
    required int totalPrice,
    int? originalTotal,
    int discountAmount = 0,
    int discountPercent = 0,
    int discountMinNights = 0,
    String discountBase = '',
    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,
    required Map<String, dynamic>? addonData,
  }) {
    final Map<String, int> customServicePrices = {};

    for (final entry in selectedCustomServices.entries) {
      final name = entry.key;

      final service = (addonData?['customServices'] ?? []).firstWhere(
        (e) => e['name'] == name,
        orElse: () => {},
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
      originalTotal: originalTotal,
      discountAmount: discountAmount,
      discountPercent: discountPercent,
      discountMinNights: discountMinNights,
      discountBase: discountBase,
      timeAddon: selectedTimeAddon,
      valueServices: selectedValueServices,
      customServices: selectedCustomServices,
      customServicePrices: customServicePrices,
    );
  }
}
