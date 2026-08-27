// lib/core/models/inventory_binding_model.dart
// 📦 功能綁定中央庫存 Model
// 功能：加購服務、每日分時段服務與未來商城都可選綁多個庫存品項。
// 未設定時視為不使用庫存，舊資料可完全向下相容。

class InventoryBindingModel {
  const InventoryBindingModel({
    required this.inventoryItemId,
    this.inventoryItemName = '',
    this.unit = '',
    this.quantityPerUnit = 1,
  });

  final String inventoryItemId;
  final String inventoryItemName;
  final String unit;
  final num quantityPerUnit;

  bool get isValid {
    return inventoryItemId.trim().isNotEmpty && quantityPerUnit > 0;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'inventoryItemId': inventoryItemId.trim(),
      'inventoryItemName': inventoryItemName.trim(),
      'unit': unit.trim(),
      'quantityPerUnit': quantityPerUnit,
    };
  }

  factory InventoryBindingModel.fromMap(Map<String, dynamic> data) {
    return InventoryBindingModel(
      inventoryItemId: (data['inventoryItemId'] ?? '').toString(),
      inventoryItemName: (data['inventoryItemName'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      quantityPerUnit: data['quantityPerUnit'] is num
          ? data['quantityPerUnit'] as num
          : num.tryParse(data['quantityPerUnit']?.toString() ?? '') ?? 1,
    );
  }

  static List<InventoryBindingModel> listFromValue(dynamic value) {
    if (value is! List) {
      return const <InventoryBindingModel>[];
    }

    return value
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) =>
              InventoryBindingModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .where((InventoryBindingModel item) => item.isValid)
        .toList();
  }
}
