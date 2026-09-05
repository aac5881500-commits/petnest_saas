// 檔案名稱：lib/core/models/inventory_consumption_model.dart
// 功能說明：以確定性 document ID 記錄加購、點數兌換、住宿耗材是否已扣庫存或已返還
// 📦 庫存消耗／返還幂等紀錄 Model
// 防止連點、重送、callback 重複造成超賣或重複補庫存。

import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryConsumptionLine {
  const InventoryConsumptionLine({
    required this.inventoryItemId,
    required this.quantity,
    required this.movementId,
    required this.stockBefore,
    required this.stockAfter,
    this.itemName = '',
    this.unit = '',
  });

  final String inventoryItemId;
  final num quantity;
  final String movementId;
  final num stockBefore;
  final num stockAfter;
  final String itemName;
  final String unit;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'inventoryItemId': inventoryItemId,
      'quantity': quantity,
      'movementId': movementId,
      'stockBefore': stockBefore,
      'stockAfter': stockAfter,
      'itemName': itemName,
      'unit': unit,
    };
  }

  factory InventoryConsumptionLine.fromMap(Map<String, dynamic> data) {
    return InventoryConsumptionLine(
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      quantity: data['quantity'] is num
          ? data['quantity'] as num
          : num.tryParse(data['quantity']?.toString() ?? '') ?? 0,
      movementId: (data['movementId'] ?? '').toString(),
      stockBefore: data['stockBefore'] is num
          ? data['stockBefore'] as num
          : num.tryParse(data['stockBefore']?.toString() ?? '') ?? 0,
      stockAfter: data['stockAfter'] is num
          ? data['stockAfter'] as num
          : num.tryParse(data['stockAfter']?.toString() ?? '') ?? 0,
      itemName: (data['itemName'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
    );
  }
}

class InventoryConsumptionModel {
  const InventoryConsumptionModel({
    required this.id,
    required this.shopId,
    required this.sourceType,
    required this.sourceId,
    required this.operation,
    required this.status,
    required this.lines,
    required this.createdAt,
    this.createdBy = '',
    this.note = '',
  });

  final String id;
  final String shopId;
  final String sourceType;
  final String sourceId;
  final String operation;
  final String status;
  final List<InventoryConsumptionLine> lines;
  final String createdBy;
  final String note;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'operation': operation,
      'status': status,
      'lines': lines
          .map((InventoryConsumptionLine line) => line.toMap())
          .toList(),
      'createdBy': createdBy,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InventoryConsumptionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final List<InventoryConsumptionLine> lines = <InventoryConsumptionLine>[];
    final Object? rawLines = data['lines'];

    if (rawLines is List) {
      for (final Object? rawLine in rawLines) {
        if (rawLine is Map) {
          lines.add(
            InventoryConsumptionLine.fromMap(
              Map<String, dynamic>.from(rawLine),
            ),
          );
        }
      }
    }

    return InventoryConsumptionModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      sourceType: (data['sourceType'] ?? '').toString(),
      sourceId: (data['sourceId'] ?? '').toString(),
      operation: (data['operation'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      lines: lines,
      createdBy: (data['createdBy'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
