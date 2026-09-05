// 檔案名稱：lib/core/models/inventory_movement_model.dart
// 功能說明：記錄每一次庫存增減的不可刪除流水，包含異動前後數量、來源與成本。
// 📦 庫存異動流水 Model

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';

class InventoryMovementModel {
  const InventoryMovementModel({
    required this.id,
    required this.shopId,
    required this.inventoryItemId,
    required this.type,
    required this.quantityChange,
    required this.stockBefore,
    required this.stockAfter,
    required this.sourceType,
    required this.createdAt,
    this.sourceId = '',
    this.sourceSubId = '',
    this.unitCost = 0,
    this.reason = '',
    this.note = '',
    this.createdBy = '',
    this.itemNameSnapshot = '',
    this.unitSnapshot = '',
  });

  final String id;
  final String shopId;
  final String inventoryItemId;
  final InventoryMovementType type;
  final num quantityChange;
  final num stockBefore;
  final num stockAfter;
  final InventorySourceType sourceType;
  final String sourceId;
  final String sourceSubId;
  final num unitCost;
  final String reason;
  final String note;
  final String createdBy;
  final DateTime createdAt;
  final String itemNameSnapshot;
  final String unitSnapshot;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'inventoryItemId': inventoryItemId,
      'type': InventoryConstants.movementTypeValue(type),
      'quantityChange': quantityChange,
      'stockBefore': stockBefore,
      'stockAfter': stockAfter,
      'sourceType': InventoryConstants.sourceTypeValue(sourceType),
      'sourceId': sourceId,
      'sourceSubId': sourceSubId,
      'unitCost': unitCost,
      'reason': reason.trim(),
      'note': note.trim(),
      'createdBy': createdBy,
      'itemNameSnapshot': itemNameSnapshot,
      'unitSnapshot': unitSnapshot,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InventoryMovementModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return InventoryMovementModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      type: InventoryConstants.movementTypeFromValue(
        (data['type'] ?? '').toString(),
      ),
      quantityChange: _numFromValue(data['quantityChange']),
      stockBefore: _numFromValue(data['stockBefore']),
      stockAfter: _numFromValue(data['stockAfter']),
      sourceType: InventoryConstants.sourceTypeFromValue(
        (data['sourceType'] ?? '').toString(),
      ),
      sourceId: (data['sourceId'] ?? '').toString(),
      sourceSubId: (data['sourceSubId'] ?? '').toString(),
      unitCost: _numFromValue(data['unitCost']),
      reason: (data['reason'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      itemNameSnapshot: (data['itemNameSnapshot'] ?? '').toString(),
      unitSnapshot: (data['unitSnapshot'] ?? '').toString(),
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
    );
  }
}

num _numFromValue(dynamic value) {
  if (value is num) {
    return value;
  }

  return num.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTimeFromValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}
