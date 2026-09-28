// 檔案名稱：lib/core/models/booking_supply_setting_model.dart
// 功能說明：同一筆服務耗材可套用住宿、安親，或兩者。舊文件沒有新欄位時只套用住宿。
// 🧹 住宿／安親耗材設定 Model

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';

class BookingSupplySettingModel {
  const BookingSupplySettingModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.quantityPerUnit,
    required this.deductionMode,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.useInventory = false,
    this.inventoryItemId = '',
    this.inventoryItemName = '',
    this.unit = '',
    this.note = '',
    this.createdBy = '',
    this.updatedBy = '',
    this.appliesToStay = true,
    this.appliesToDaycare = false,
    num? stayQuantityPerUnit,
    BookingSupplyDeductionMode? stayDeductionMode,
    this.daycareQuantityPerUnit = 1,
    this.daycareDeductionMode = DaycareSupplyDeductionMode.perRoomPerVisit,
  }) : stayQuantityPerUnit = stayQuantityPerUnit ?? quantityPerUnit,
       stayDeductionMode = stayDeductionMode ?? deductionMode;

  final String id;
  final String shopId;
  final String name;
  final bool useInventory;
  final String inventoryItemId;
  final String inventoryItemName;
  final String unit;
  final num quantityPerUnit;
  final BookingSupplyDeductionMode deductionMode;
  final bool enabled;
  final String note;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool appliesToStay;
  final bool appliesToDaycare;
  final num stayQuantityPerUnit;
  final BookingSupplyDeductionMode stayDeductionMode;
  final num daycareQuantityPerUnit;
  final DaycareSupplyDeductionMode daycareDeductionMode;

  bool get hasInventoryTarget {
    return useInventory && inventoryItemId.trim().isNotEmpty;
  }

  bool get shouldDeductForStay {
    return enabled && hasInventoryTarget && appliesToStay;
  }

  bool get shouldDeductForDaycare {
    return enabled && hasInventoryTarget && appliesToDaycare;
  }

  /// 舊呼叫點的住宿扣除判斷。安親專用設定不會走這裡。
  bool get shouldDeductInventory => shouldDeductForStay;

  num get stayQuantity => stayQuantityPerUnit;

  num get daycareQuantity => daycareQuantityPerUnit;

  BookingSupplyDeductionMode get stayMode => stayDeductionMode;

  DaycareSupplyDeductionMode get daycareMode => daycareDeductionMode;

  num stayDeductQuantity({required int nights, required int petCount}) {
    final int safeNights = nights <= 0 ? 1 : nights;
    final int safePets = petCount <= 0 ? 1 : petCount;
    final num multiplier = switch (stayDeductionMode) {
      BookingSupplyDeductionMode.perRoomPerNight => safeNights,
      BookingSupplyDeductionMode.perRoomPerStay => 1,
      BookingSupplyDeductionMode.perPetPerNight => safePets * safeNights,
      BookingSupplyDeductionMode.perPetPerStay => safePets,
    };
    return InventoryConstants.roundQuantity(stayQuantityPerUnit * multiplier);
  }

  num daycareDeductQuantity({required int petCount}) {
    final int safePets = petCount <= 0 ? 1 : petCount;
    final num multiplier = switch (daycareDeductionMode) {
      DaycareSupplyDeductionMode.perRoomPerVisit => 1,
      DaycareSupplyDeductionMode.perPetPerVisit => safePets,
    };
    return InventoryConstants.roundQuantity(
      daycareQuantityPerUnit * multiplier,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'useInventory': useInventory,
      'inventoryItemId': inventoryItemId.trim(),
      'inventoryItemName': inventoryItemName.trim(),
      'unit': unit.trim(),
      'quantityPerUnit': stayQuantityPerUnit,
      'deductionMode': InventoryConstants.deductionModeValue(stayDeductionMode),
      'appliesToStay': appliesToStay,
      'appliesToDaycare': appliesToDaycare,
      'stayQuantityPerUnit': stayQuantityPerUnit,
      'stayDeductionMode': InventoryConstants.deductionModeValue(
        stayDeductionMode,
      ),
      'daycareQuantityPerUnit': daycareQuantityPerUnit,
      'daycareDeductionMode': InventoryConstants.daycareDeductionModeValue(
        daycareDeductionMode,
      ),
      'enabled': enabled,
      'note': note.trim(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory BookingSupplySettingModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final num legacyQuantity = _numFrom(data['quantityPerUnit']);
    final BookingSupplyDeductionMode legacyMode =
        InventoryConstants.deductionModeFromValue(
          (data['deductionMode'] ?? '').toString(),
        );
    final bool hasStayQuantity = data.containsKey('stayQuantityPerUnit');
    final bool hasStayMode = data.containsKey('stayDeductionMode');
    return BookingSupplySettingModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      useInventory: data['useInventory'] == true,
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemName: (data['inventoryItemName'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      quantityPerUnit: legacyQuantity,
      deductionMode: legacyMode,
      appliesToStay: data.containsKey('appliesToStay')
          ? data['appliesToStay'] == true
          : true,
      appliesToDaycare: data['appliesToDaycare'] == true,
      stayQuantityPerUnit: hasStayQuantity
          ? _numFrom(data['stayQuantityPerUnit'])
          : legacyQuantity,
      stayDeductionMode: hasStayMode
          ? InventoryConstants.deductionModeFromValue(
              (data['stayDeductionMode'] ?? '').toString(),
            )
          : legacyMode,
      daycareQuantityPerUnit: data.containsKey('daycareQuantityPerUnit')
          ? _numFrom(data['daycareQuantityPerUnit'])
          : 1,
      daycareDeductionMode: InventoryConstants.daycareDeductionModeFromValue(
        (data['daycareDeductionMode'] ?? '').toString(),
      ),
      enabled: data['enabled'] != false,
      note: (data['note'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      updatedBy: (data['updatedBy'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

num _numFrom(Object? value) {
  if (value is num) {
    if (value.isNaN || value.isInfinite) {
      return 0;
    }
    return value;
  }
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

class BookingSupplyDeductLine {
  const BookingSupplyDeductLine({
    required this.inventoryItemId,
    required this.quantity,
    required this.reason,
    required this.settingId,
  });

  final String inventoryItemId;
  final num quantity;
  final String reason;
  final String settingId;
}

class BookingSupplyDeduction {
  BookingSupplyDeduction._();

  static int petCountOf(Map<String, dynamic> booking) {
    final Object? petIds = booking['petIds'];
    if (petIds is List && petIds.isNotEmpty) {
      return petIds.length;
    }
    final Object? pets = booking['pets'];
    if (pets is List && pets.isNotEmpty) {
      return pets.length;
    }
    return 1;
  }

  static int nightCountOf(Map<String, dynamic> booking) {
    final Object? nights = booking['nights'];
    if (nights is num && nights > 0 && nights.isFinite) {
      return nights.toInt();
    }
    return 1;
  }

  static List<BookingSupplyDeductLine> stayLines({
    required Map<String, dynamic> booking,
    required List<BookingSupplySettingModel> settings,
  }) {
    final int nights = nightCountOf(booking);
    final int petCount = petCountOf(booking);
    final List<BookingSupplyDeductLine> lines = <BookingSupplyDeductLine>[];
    for (final BookingSupplySettingModel setting in settings) {
      if (!setting.shouldDeductForStay) {
        continue;
      }
      final num quantity = setting.stayDeductQuantity(
        nights: nights,
        petCount: petCount,
      );
      if (quantity <= 0) {
        continue;
      }
      lines.add(
        BookingSupplyDeductLine(
          inventoryItemId: setting.inventoryItemId.trim(),
          quantity: quantity,
          reason: '住宿耗材「${setting.name}」',
          settingId: setting.id,
        ),
      );
    }
    return lines;
  }

  static List<BookingSupplyDeductLine> daycareLines({
    required Map<String, dynamic> booking,
    required List<BookingSupplySettingModel> settings,
  }) {
    final int petCount = petCountOf(booking);
    final List<BookingSupplyDeductLine> lines = <BookingSupplyDeductLine>[];
    for (final BookingSupplySettingModel setting in settings) {
      if (!setting.shouldDeductForDaycare) {
        continue;
      }
      final num quantity = setting.daycareDeductQuantity(petCount: petCount);
      if (quantity <= 0) {
        continue;
      }
      lines.add(
        BookingSupplyDeductLine(
          inventoryItemId: setting.inventoryItemId.trim(),
          quantity: quantity,
          reason: '安親耗材「${setting.name}」',
          settingId: setting.id,
        ),
      );
    }
    return lines;
  }
}
