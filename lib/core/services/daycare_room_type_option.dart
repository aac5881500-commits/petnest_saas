// lib/core/services/daycare_room_type_option.dart
// 🐾 前台安親房型／計價方案：以 room_types document id 對應 roomTypeId

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';

class DaycareRoomTypeOption {
  const DaycareRoomTypeOption({
    required this.roomTypeId,
    required this.name,
    required this.setting,
    required this.capacity,
    required this.selectable,
    this.blockedReason,
    this.estimateAmount = 0,
    this.overtimeSummary = '',
    this.isRoomBased = true,
  });

  final String roomTypeId;
  final String name;
  final DaycareRoomTypeSetting setting;
  final int capacity;
  final bool selectable;
  final String? blockedReason;
  final int estimateAmount;
  final String overtimeSummary;
  final bool isRoomBased;

  String get billingLabel {
    final String included = setting.includedMinutes % 60 == 0
        ? '${setting.includedMinutes ~/ 60} 小時'
        : '${setting.includedMinutes} 分鐘';
    final String extra = setting.extraBillingMinutes == 30 ? '每 30 分鐘' : '每小時';
    return '$included NT\$${setting.basePrice}・超過後$extra NT\$${setting.extraBillingPrice}';
  }

  String get extraPetLabel {
    if (setting.extraPetPrice <= 0) {
      return '';
    }
    return '每多 1 隻 +NT\$${setting.extraPetPrice}';
  }

  String get capacitySummary => '最多 ${setting.maxPets} 隻';
}

class DaycareRoomTypeCatalog {
  DaycareRoomTypeCatalog._();

  static DaycareRoomTypeOption evaluate({
    required DaycareRoomTypeSetting setting,
    required String name,
    required int petCount,
    int? dailyRemaining,
    int estimateAmount = 0,
    String overtimeSummary = '',
    bool typeExists = true,
    bool isRoomBased = true,
  }) {
    String? reason;
    if (!setting.enabled) {
      reason = '房型未啟用';
    } else if (!typeExists) {
      reason = '房型未啟用';
    } else if (petCount > 0 && petCount > setting.maxPets) {
      reason = '寵物數量超過容量';
    } else if (dailyRemaining != null &&
        dailyRemaining >= 0 &&
        petCount > 0 &&
        dailyRemaining < petCount) {
      reason = '當日名額已滿';
    }
    return DaycareRoomTypeOption(
      roomTypeId: setting.roomTypeId,
      name: name,
      setting: setting,
      capacity: setting.maxPets,
      selectable: reason == null,
      blockedReason: reason,
      estimateAmount: estimateAmount,
      overtimeSummary: overtimeSummary,
      isRoomBased: isRoomBased,
    );
  }

  static Future<List<DaycareRoomTypeOption>> load({
    required String shopId,
    required DaycareSettingsModel settings,
    required int petCount,
    int? dailyRemaining,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    if (settings.roomTypes.isEmpty) {
      return const <DaycareRoomTypeOption>[];
    }
    final QuerySnapshot<Map<String, dynamic>> typeSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('room_types')
        .get();
    final Map<String, Map<String, dynamic>> types =
        <String, Map<String, dynamic>>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
              in typeSnap.docs)
            doc.id: doc.data(),
        };

    final List<DaycareRoomTypeOption> out = <DaycareRoomTypeOption>[];
    for (final DaycareRoomTypeSetting setting in settings.roomTypes) {
      final String id = setting.roomTypeId.trim();
      if (id.isEmpty) {
        continue;
      }
      final Map<String, dynamic>? type = types[id];
      int estimate = 0;
      String overtimeSummary = '';
      if (startAt != null && endAt != null) {
        final DaycareRoomQuote roomQuote = DaycarePricingService.instance
            .quoteRoom(
              roomSetting: setting,
              startAt: startAt,
              endAt: endAt,
              petCount: petCount < 1 ? 1 : petCount,
            );
        estimate = roomQuote.cappedRoomAmount;
        overtimeSummary = DaycarePricingService.instance.overtimeRuleSummary(
          settings: settings,
          roomSetting: setting,
        );
      }
      out.add(
        evaluate(
          setting: setting,
          name: (type?['name'] ?? id).toString(),
          petCount: petCount,
          dailyRemaining: dailyRemaining,
          estimateAmount: estimate,
          overtimeSummary: overtimeSummary,
          typeExists: type != null,
          isRoomBased: settings.isRoomBased,
        ),
      );
    }
    return out;
  }

  static String emptyReason(List<DaycareRoomTypeOption> options) {
    if (options.isEmpty) {
      return '尚未設定安親房型';
    }
    return '目前沒有符合條件的安親房型';
  }
}
