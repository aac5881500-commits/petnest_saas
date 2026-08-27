// lib/core/models/inventory_batch_model.dart
// 📦 庫存進貨批次 Model
// 功能：保存同一品項的多批進貨紀錄，包含數量、單價、總成本、有效期限與供應商。

import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryBatchModel {
  const InventoryBatchModel({
    required this.id,
    required this.shopId,
    required this.inventoryItemId,
    required this.quantityReceived,
    required this.remainingQuantity,
    required this.unitCost,
    required this.totalCost,
    required this.receivedAt,
    required this.createdAt,
    this.batchNo = '',
    this.expiryDate,
    this.supplier = '',
    this.note = '',
    this.createdBy = '',
  });

  final String id;
  final String shopId;
  final String inventoryItemId;
  final String batchNo;
  final num quantityReceived;
  final num remainingQuantity;
  final num unitCost;
  final num totalCost;
  final DateTime receivedAt;
  final DateTime? expiryDate;
  final String supplier;
  final String note;
  final String createdBy;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shopId': shopId,
      'inventoryItemId': inventoryItemId,
      'batchNo': batchNo.trim(),
      'quantityReceived': quantityReceived,
      'remainingQuantity': remainingQuantity,
      'unitCost': unitCost,
      'totalCost': totalCost,
      'receivedAt': Timestamp.fromDate(receivedAt),
      'expiryDate': expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
      'supplier': supplier.trim(),
      'note': note.trim(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory InventoryBatchModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return InventoryBatchModel(
      id: id,
      shopId: (data['shopId'] ?? '').toString(),
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      batchNo: (data['batchNo'] ?? '').toString(),
      quantityReceived: _numFromValue(data['quantityReceived']),
      remainingQuantity: _numFromValue(data['remainingQuantity']),
      unitCost: _numFromValue(data['unitCost']),
      totalCost: _numFromValue(data['totalCost']),
      receivedAt: _dateTimeFromValue(data['receivedAt']) ?? DateTime.now(),
      expiryDate: _dateTimeFromValue(data['expiryDate']),
      supplier: (data['supplier'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
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
