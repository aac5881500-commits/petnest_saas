// 檔案名稱：lib/core/services/daycare_callable_payload.dart
// 功能說明：安親 createDaycareBooking callable 專用純資料快照。

import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/models/pet_snapshot.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';

class DaycareCallablePayload {
  DaycareCallablePayload._();

  static Map<String, dynamic> planSnapshot(DaycarePlanModel plan) {
    return <String, dynamic>{
      'id': plan.id,
      'name': plan.name,
      'description': plan.description,
      'enabled': plan.enabled,
      'includedMinutes': plan.includedMinutes,
      'basePrice': plan.basePrice,
      'extraBillingMinutes': plan.extraBillingMinutes,
      'extraBillingPrice': plan.extraBillingPrice,
      'extraPetPrice': plan.extraPetPrice,
      'maxBaseCharge': plan.maxBaseCharge,
      'maxPets': plan.maxPets,
      'sortOrder': plan.sortOrder,
    };
  }

  static Map<String, dynamic> roomSnapshot(DaycareRoomTypeSetting? room) {
    if (room == null) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{
      'roomTypeId': room.roomTypeId,
      'enabled': room.enabled,
      'includedMinutes': room.includedMinutes,
      'basePrice': room.basePrice,
      'extraBillingMinutes': room.extraBillingMinutes,
      'extraBillingPrice': room.extraBillingPrice,
      'extraPetPrice': room.extraPetPrice,
      'maxBaseCharge': room.maxBaseCharge,
      'maxPets': room.maxPets,
    };
  }

  static Map<String, dynamic> petSnapshot(Map<String, dynamic> pet) {
    final Map<String, dynamic> out = PetSnapshot.fromPet(pet);
    for (final String key in <String>[
      'petFormAnswers',
      'adminPetFormAnswers',
    ]) {
      final Object? raw = pet[key];
      if (raw is Map) {
        out[key] = Map<String, dynamic>.from(raw);
      }
    }
    return out;
  }

  static Map<String, dynamic> addonSnapshot(
    Map<String, dynamic> addon, {
    required int amount,
  }) {
    final Object? rawPetIds = addon['selectedPetIds'];
    final List<String> petIds = <String>[];
    if (rawPetIds is Iterable) {
      for (final Object? id in rawPetIds) {
        final String text = id.toString();
        if (text.isNotEmpty) {
          petIds.add(text);
        }
      }
    }
    final List<Map<String, dynamic>> slots = <Map<String, dynamic>>[];
    final Object? rawSlots = addon['selectedTimeSlots'];
    if (rawSlots is Iterable) {
      for (final Object? item in rawSlots) {
        if (item is Map) {
          slots.add(<String, dynamic>{
            'id': (item['id'] ?? item['label'] ?? '').toString(),
            'label': (item['label'] ?? item['id'] ?? '').toString(),
          });
        } else {
          final String label = item.toString().trim();
          if (label.isNotEmpty) {
            slots.add(<String, dynamic>{'id': label, 'label': label});
          }
        }
      }
    }
    return <String, dynamic>{
      'id': (addon['id'] ?? '').toString(),
      'name': (addon['name'] ?? addon['label'] ?? '').toString(),
      'type': (addon['type'] ?? '').toString(),
      'price': SafeParse.parseMoney(addon['price']),
      'count': SafeParse.parseMoney(addon['count'], fallback: 1),
      'daycareChargeMode': (addon['daycareChargeMode'] ?? '').toString(),
      'slotCount': SafeParse.parseMoney(addon['slotCount']),
      'amount': amount,
      'selectedPetIds': petIds,
      'selectedTimeSlots': slots,
    };
  }

  static Map<String, dynamic> adminCreateBookingData({
    required String shopId,
    required String userId,
    required String customerName,
    required String customerPhone,
    required String scheduledStartAt,
    required String scheduledEndAt,
    required List<String> petIds,
    required List<Map<String, dynamic>> pets,
    required String pricingMode,
    required String daycarePlanId,
    required String daycarePlanName,
    required Map<String, dynamic> daycarePlanPriceSnapshot,
    required String requestedRoomTypeId,
    required String requestedRoomTypeName,
    required Map<String, dynamic> requestedRoomTypePriceSnapshot,
    required List<Map<String, dynamic>> addons,
    required int manualAdjust,
    required int policyVersion,
    required String policyKind,
    required String policySignMethod,
    required String paymentMethod,
    required String termsType,
    required String note,
    String adminOrderSource = '',
    Map<String, dynamic>? adminCustomFormAnswers,
    Map<String, dynamic>? adminPetFormAnswersByPetId,
    required String requestId,
    String dailyCareAddonId = '',
  }) {
    return <String, dynamic>{
      'shopId': shopId,
      'source': 'admin',
      'userId': userId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'scheduledStartAt': scheduledStartAt,
      'scheduledEndAt': scheduledEndAt,
      'petIds': List<String>.from(petIds),
      'pets': pets.map(petSnapshot).toList(),
      'pricingMode': pricingMode,
      'daycarePlanId': daycarePlanId,
      'daycarePlanName': daycarePlanName,
      'daycarePlanPriceSnapshot': daycarePlanPriceSnapshot,
      'requestedRoomTypeId': requestedRoomTypeId,
      'requestedRoomTypeName': requestedRoomTypeName,
      'requestedRoomTypePriceSnapshot': requestedRoomTypePriceSnapshot,
      'dailyCareAddonId': dailyCareAddonId,
      'addons': addons,
      'manualAdjust': manualAdjust,
      'policyVersion': policyVersion,
      'policyKind': policyKind,
      'policySignMethod': policySignMethod,
      'paymentMethod': paymentMethod,
      'termsType': termsType,
      'note': note,
      'adminOrderSource': adminOrderSource,
      if (adminCustomFormAnswers != null)
        'adminCustomFormAnswers': adminCustomFormAnswers,
      if (adminPetFormAnswersByPetId != null &&
          adminPetFormAnswersByPetId.isNotEmpty)
        'adminPetFormAnswersByPetId': adminPetFormAnswersByPetId,
      'requestId': requestId,
    };
  }
}
