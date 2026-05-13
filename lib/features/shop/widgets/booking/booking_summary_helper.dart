// lib/features/shop/widgets/booking/booking_summary_helper.dart
// 🔥 前台預約確認 helper：負責計算價格與建立 summary card

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_summary_card.dart';

class BookingSummaryHelper {
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
    final basePrice =
        (selectedRoomType['price'] ?? 0).toInt();

    int total = basePrice * nights;

    /// 🔥 多貓價格
    final petCount = selectedPetIds.length;
    final extraPrice =
        (selectedRoomType['extraPrice'] ?? 0).toInt();

    if (petCount > 1) {
      final extraCount = petCount - 1;

      total +=
          (extraCount * extraPrice * nights).toInt();
    }

    /// 🔥 時間加購
    if (selectedTimeAddon != null) {
      total +=
          (selectedTimeAddon['price'] ?? 0) as int;
    }

    /// 🔥 加值服務
    for (var item in selectedValueServices) {
      total += (item['price'] ?? 0) as int;
    }

    /// 🔥 客製化服務
    for (var entry in selectedCustomServices.entries) {
      final serviceName = entry.key;
      final selectedPets = entry.value;

      final service =
          (addonData?['customServices'] ?? [])
              .firstWhere(
        (e) => e['name'] == serviceName,
        orElse: () => {},
      );

      final price = (service['price'] ?? 0) as int;

      total += price * selectedPets.length;
    }

    return total;
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
    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,
    required Map<String, dynamic>? addonData,
  }) {
    final Map<String, int> customServicePrices = {};

    for (final entry
        in selectedCustomServices.entries) {
      final name = entry.key;

      final service =
          (addonData?['customServices'] ?? [])
              .firstWhere(
        (e) => e['name'] == name,
        orElse: () => {},
      );

      customServicePrices[name] =
          (service['price'] ?? 0) as int;
    }

    return BookingSummaryCard(
      startDateText: startDateText,
      endDateText: endDateText,
      nights: nights,
      petCount: selectedPetIds.length,
      roomTypeName:
          selectedRoomType['name'] ?? '',
      totalPrice: totalPrice,
      timeAddon: selectedTimeAddon,
      valueServices: selectedValueServices,
      customServices: selectedCustomServices,
      customServicePrices: customServicePrices,
    );
  }
}