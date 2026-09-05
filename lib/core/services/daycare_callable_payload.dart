// 檔案名稱：lib/core/services/daycare_callable_payload.dart
// 功能說明：安親 createDaycareBooking callable 專用純資料快照。

import 'package:petnest_saas/core/models/daycare_plan_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
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
    final Object? rawNeutered = pet['isNeutered'];
    return <String, dynamic>{
      'petId': (pet['petId'] ?? pet['id'] ?? '').toString(),
      'name': (pet['name'] ?? '').toString(),
      'breed': (pet['breed'] ?? pet['type'] ?? '').toString(),
      'gender': (pet['gender'] ?? '').toString(),
      'isNeutered': rawNeutered == null
          ? null
          : SafeParse.parseBool(rawNeutered),
      'photoUrl': (pet['photoUrl'] ?? '').toString(),
    };
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
    };
  }
}
