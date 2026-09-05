// 檔案名稱：lib/core/models/booking_supply_setting_model.dart
// 功能說明：店家可手動記錄一般用品，或綁定中央庫存並依每房／每寵物、每晚／每次入住扣除。
// 🧹 住宿耗材／必要用品設定 Model

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
  });

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

  bool get shouldDeductInventory {
    return enabled && useInventory && inventoryItemId.trim().isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'name': name.trim(),
      'useInventory': useInventory,
      'inventoryItemId': inventoryItemId.trim(),
      'inventoryItemName': inventoryItemName.trim(),
      'unit': unit.trim(),
      'quantityPerUnit': quantityPerUnit,
      'deductionMode': InventoryConstants.deductionModeValue(deductionMode),
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
    return BookingSupplySettingModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      useInventory: data['useInventory'] == true,
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemName: (data['inventoryItemName'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      quantityPerUnit: data['quantityPerUnit'] is num
          ? data['quantityPerUnit'] as num
          : num.tryParse(data['quantityPerUnit']?.toString() ?? '') ?? 0,
      deductionMode: InventoryConstants.deductionModeFromValue(
        (data['deductionMode'] ?? '').toString(),
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
