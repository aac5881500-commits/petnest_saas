// 檔案名稱：lib/core/services/daycare_room_type_option.dart
// 功能說明：前台安親房型／計價方案：以 room_types document id 對應 roomTypeId

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_pricing_service.dart';

class DaycareRoomTypeOption {
  const DaycareRoomTypeOption({
    required this.roomTypeId,
    required this.name,
    required this.setting,
    required this.capacity,
    required this.selectable,
    this.blockedReason,
    this.remainingRooms,
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
  final int? remainingRooms;
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

  String get capacitySummary =>
      capacity > 0 ? '最多 $capacity 隻' : '請確認房型容納數';
}

class DaycareRoomTypeCatalog {
  DaycareRoomTypeCatalog._();

  static DaycareRoomTypeOption evaluate({
    required DaycareRoomTypeSetting setting,
    required String name,
    required int petCount,
    int? dailyRemaining,
    int? remainingRooms,
    int estimateAmount = 0,
    String overtimeSummary = '',
    bool typeExists = true,
    bool isRoomBased = true,
    int roomCapacity = 0,
  }) {
    final int capacity = roomCapacity > 0 ? roomCapacity : 0;
    String? reason;
    if (!setting.enabled) {
      reason = '房型未啟用';
    } else if (!typeExists) {
      reason = '找不到對應房型資料，請聯絡店家';
    } else if (petCount > 0 && capacity > 0 && petCount > capacity) {
      reason = '此房型最多容納 $capacity 隻寵物';
    } else if (dailyRemaining != null &&
        dailyRemaining >= 0 &&
        petCount > 0 &&
        dailyRemaining < petCount) {
      reason = '當日名額已滿';
    } else if (remainingRooms != null && remainingRooms <= 0) {
      reason = '此房型目前沒有空房';
    }
    return DaycareRoomTypeOption(
      roomTypeId: setting.roomTypeId,
      name: name,
      setting: setting,
      capacity: capacity,
      selectable: reason == null,
      blockedReason: reason,
      remainingRooms: remainingRooms,
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

    final QuerySnapshot<Map<String, dynamic>> roomSnap = await FirebaseFirestore
        .instance
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .get();
    final QuerySnapshot<Map<String, dynamic>> bookingSnap =
        await FirebaseFirestore.instance
            .collection('bookings')
            .where('shopId', isEqualTo: shopId)
            .where('status', whereIn: DaycareOccupancyService.activeStatuses)
            .get();
    final List<Map<String, dynamic>> rooms = roomSnap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();
    final List<Map<String, dynamic>> bookings = bookingSnap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              <String, dynamic>{'id': doc.id, ...doc.data()},
        )
        .toList();

    final List<DaycareRoomTypeOption> out = <DaycareRoomTypeOption>[];
    for (final DaycareRoomTypeSetting setting in settings.roomTypes) {
      final String id = setting.roomTypeId.trim();
      if (id.isEmpty) {
        continue;
      }
      final Map<String, dynamic>? type = resolveRoomTypeDoc(types, id);
      final bool hasRooms = rooms.any(
        (Map<String, dynamic> room) =>
            (room['roomTypeId'] ?? '').toString().trim() == id,
      );
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
      int? remainingRooms;
      if (startAt != null && endAt != null) {
        remainingRooms = DaycareOccupancyService.remainingRoomsFromData(
          rooms: rooms,
          bookings: bookings,
          roomTypeId: id,
          startAt: startAt,
          endAt: endAt,
          petCount: petCount,
          roomTypeCapacity: roomCapacityOf(type, rooms, id),
        );
      }
      out.add(
        evaluate(
          setting: setting,
          name: (type?['name'] ?? id).toString(),
          petCount: petCount,
          dailyRemaining: dailyRemaining,
          remainingRooms: remainingRooms,
          estimateAmount: estimate,
          overtimeSummary: overtimeSummary,
          typeExists: type != null || hasRooms,
          isRoomBased: settings.isRoomBased,
          roomCapacity: roomCapacityOf(type, rooms, id),
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

  static Map<String, dynamic>? resolveRoomTypeDoc(
    Map<String, Map<String, dynamic>> types,
    String settingId,
  ) {
    final String id = settingId.trim();
    if (id.isEmpty) {
      return null;
    }
    if (types.containsKey(id)) {
      return types[id];
    }
    for (final MapEntry<String, Map<String, dynamic>> entry in types.entries) {
      if (entry.key.trim() == id) {
        return entry.value;
      }
      final String name = (entry.value['name'] ?? '').toString().trim();
      if (name.isNotEmpty && name == id) {
        return entry.value;
      }
    }
    return null;
  }

  static int roomCapacityOf(
    Map<String, dynamic>? type,
    List<Map<String, dynamic>> rooms,
    String roomTypeId,
  ) {
    final int fromType = ((type?['capacity'] as num?)?.toInt() ?? 0);
    if (fromType > 0) {
      return fromType;
    }
    int maxRoom = 0;
    for (final Map<String, dynamic> room in rooms) {
      if ((room['roomTypeId'] ?? '').toString().trim() != roomTypeId.trim()) {
        continue;
      }
      final int cap = (room['capacity'] as num?)?.toInt() ?? 0;
      if (cap > maxRoom) {
        maxRoom = cap;
      }
    }
    return maxRoom;
  }
}
