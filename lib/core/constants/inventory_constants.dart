// lib/core/constants/inventory_constants.dart
// 📦 中央庫存常數與列舉
// 功能：統一庫存異動類型、來源、出庫原因、住宿耗材扣除方式與 Firestore 路徑，
// 避免各功能散落 magic string，並預留未來商城使用同一套中央庫存。

import 'package:intl/intl.dart';

/// 庫存異動類型
enum InventoryMovementType {
  /// 進貨
  purchase,

  /// 手動出庫
  manualOutbound,

  /// 盤點調整
  adjustment,

  /// 加購服務
  addon,

  /// 點數實體商品兌換
  pointRedemption,

  /// 住宿耗材
  bookingSupply,

  /// 取消返還
  returnStock,

  /// 未來商城預留
  futureStore,
}

/// 庫存異動來源類型
enum InventorySourceType {
  purchase,
  manualOutbound,
  adjustment,
  addon,
  pointRedemption,
  bookingSupply,
  returnStock,
  futureStore,
}

/// 手動出庫原因
enum InventoryOutboundReason { inStoreUse, damaged, expired, gift, other }

/// 住宿耗材扣除方式
enum BookingSupplyDeductionMode {
  perRoomPerNight,
  perRoomPerStay,
  perPetPerNight,
  perPetPerStay,
}

/// 庫存狀態
enum InventoryStockStatus { normal, low, outOfStock, disabled }

class InventoryConstants {
  InventoryConstants._();

  static const String itemsCollection = 'inventory_items';
  static const String batchesCollection = 'batches';
  static const String movementsCollection = 'movements';
  static const String consumptionsCollection = 'inventory_consumptions';
  static const String bookingSupplySettingsCollection =
      'booking_supply_settings';

  static const String imageFolder = 'inventory';
  static const String coverFileName = 'cover.jpg';
  static const int coverMaxEdge = 1400;
  static const int coverJpegQuality = 85;
  static const int originalImageMaxBytes = 5 * 1024 * 1024;
  static const int movementPageLimit = 80;
  static const int recentMovementLimit = 5;

  static const String consumptionStatusCompleted = 'completed';
  static const String consumptionOperationDeduct = 'deduct';
  static const String consumptionOperationReturn = 'return';

  static const int expiryWarningDays = 30;

  static const String categoryUnspecifiedLabel = '未選擇';
  static const String categoryOther = '其他';

  static const List<String> categoryOptions = <String>[
    '食品',
    '零食',
    '飲水',
    '貓砂',
    '清潔用品',
    '醫療 / 保健',
    '日用品',
    '玩具',
    '耗材',
    '實體商品',
    categoryOther,
  ];

  static List<String> categoryDropdownOptions(String currentValue) {
    final String trimmed = currentValue.trim();
    if (trimmed.isEmpty || categoryOptions.contains(trimmed)) {
      return categoryOptions;
    }

    return <String>[...categoryOptions, trimmed];
  }

  static String movementTypeValue(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.returnStock:
        return 'return';
      default:
        return type.name;
    }
  }

  static InventoryMovementType movementTypeFromValue(String value) {
    if (value == 'return') {
      return InventoryMovementType.returnStock;
    }

    return InventoryMovementType.values.firstWhere(
      (InventoryMovementType item) => item.name == value,
      orElse: () => InventoryMovementType.adjustment,
    );
  }

  static String sourceTypeValue(InventorySourceType type) {
    switch (type) {
      case InventorySourceType.returnStock:
        return 'return';
      default:
        return type.name;
    }
  }

  static InventorySourceType sourceTypeFromValue(String value) {
    if (value == 'return') {
      return InventorySourceType.returnStock;
    }

    return InventorySourceType.values.firstWhere(
      (InventorySourceType item) => item.name == value,
      orElse: () => InventorySourceType.adjustment,
    );
  }

  static String movementTypeLabel(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.purchase:
        return '進貨';
      case InventoryMovementType.manualOutbound:
        return '手動出庫';
      case InventoryMovementType.adjustment:
        return '盤點調整';
      case InventoryMovementType.addon:
        return '加購服務';
      case InventoryMovementType.pointRedemption:
        return '點數兌換';
      case InventoryMovementType.bookingSupply:
        return '住宿耗材';
      case InventoryMovementType.returnStock:
        return '取消返還';
      case InventoryMovementType.futureStore:
        return '商城銷售';
    }
  }

  static String sourceTypeLabel(InventorySourceType type) {
    switch (type) {
      case InventorySourceType.purchase:
        return '進貨';
      case InventorySourceType.manualOutbound:
        return '手動出庫';
      case InventorySourceType.adjustment:
        return '盤點調整';
      case InventorySourceType.addon:
        return '加購服務';
      case InventorySourceType.pointRedemption:
        return '點數兌換';
      case InventorySourceType.bookingSupply:
        return '住宿耗材';
      case InventorySourceType.returnStock:
        return '取消返還';
      case InventorySourceType.futureStore:
        return '商城訂單';
    }
  }

  static String outboundReasonValue(InventoryOutboundReason reason) {
    return reason.name;
  }

  static InventoryOutboundReason outboundReasonFromValue(String value) {
    return InventoryOutboundReason.values.firstWhere(
      (InventoryOutboundReason item) => item.name == value,
      orElse: () => InventoryOutboundReason.other,
    );
  }

  static String outboundReasonLabel(InventoryOutboundReason reason) {
    switch (reason) {
      case InventoryOutboundReason.inStoreUse:
        return '店內使用';
      case InventoryOutboundReason.damaged:
        return '商品損壞';
      case InventoryOutboundReason.expired:
        return '過期';
      case InventoryOutboundReason.gift:
        return '贈送';
      case InventoryOutboundReason.other:
        return '其他';
    }
  }

  static String deductionModeValue(BookingSupplyDeductionMode mode) {
    return mode.name;
  }

  static BookingSupplyDeductionMode deductionModeFromValue(String value) {
    return BookingSupplyDeductionMode.values.firstWhere(
      (BookingSupplyDeductionMode item) => item.name == value,
      orElse: () => BookingSupplyDeductionMode.perRoomPerNight,
    );
  }

  static String deductionModeLabel(BookingSupplyDeductionMode mode) {
    switch (mode) {
      case BookingSupplyDeductionMode.perRoomPerNight:
        return '每房每晚';
      case BookingSupplyDeductionMode.perRoomPerStay:
        return '每房每次入住';
      case BookingSupplyDeductionMode.perPetPerNight:
        return '每隻寵物每晚';
      case BookingSupplyDeductionMode.perPetPerStay:
        return '每隻寵物每次入住';
    }
  }

  static String stockStatusLabel(InventoryStockStatus status) {
    switch (status) {
      case InventoryStockStatus.normal:
        return '正常';
      case InventoryStockStatus.low:
        return '低庫存';
      case InventoryStockStatus.outOfStock:
        return '缺貨';
      case InventoryStockStatus.disabled:
        return '停用';
    }
  }

  static String formatQuantity(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static num roundQuantity(num value) {
    return num.parse(value.toStringAsFixed(4));
  }

  /// 金額總成本存 2 位小數，避免 999.999 這類浮點誤差寫進 Firestore。
  static num roundMoney(num value) {
    return num.parse(value.toStringAsFixed(2));
  }

  /// 加權平均單價保留較高內部精度，畫面再格式化成最多 2 位。
  static num roundUnitCost(num value) {
    if (value == 0) {
      return 0;
    }

    return num.parse(value.toStringAsFixed(8));
  }

  static num batchTotalCost({required num quantity, required num unitCost}) {
    return roundMoney(quantity * unitCost);
  }

  /// 由獨立庫存總成本推導加權平均，不反過來用平均去回推總成本。
  static num weightedAverageFromCost({
    required num estimatedStockCost,
    required num currentStock,
    num fallbackUnitCost = 0,
  }) {
    if (currentStock <= 0) {
      return roundUnitCost(fallbackUnitCost);
    }

    return roundUnitCost(estimatedStockCost / currentStock);
  }

  /// 出庫／盤點／自動扣還：依庫存比例調整獨立總成本，不用已四捨五入的平均單價重算。
  static num remainingStockCost({
    required num currentEstimatedCost,
    required num stockBefore,
    required num stockAfter,
    num fallbackUnitCost = 0,
  }) {
    if (stockAfter <= 0) {
      return 0;
    }

    if (stockBefore > 0) {
      return roundMoney(currentEstimatedCost * stockAfter / stockBefore);
    }

    return roundMoney(stockAfter * fallbackUnitCost);
  }

  static String formatMoney(num value) {
    final num rounded = roundMoney(value);

    if (rounded % 1 == 0) {
      return NumberFormat('#,##0', 'en_US').format(rounded);
    }

    return NumberFormat('#,##0.00', 'en_US').format(rounded);
  }

  static String consumptionId({
    required String prefix,
    required String sourceId,
    required String operation,
  }) {
    return '${prefix}_${sourceId.trim()}_$operation';
  }

  static String redemptionDeductId(String redemptionId) {
    return consumptionId(
      prefix: 'pr',
      sourceId: redemptionId,
      operation: consumptionOperationDeduct,
    );
  }

  static String redemptionReturnId(String redemptionId) {
    return consumptionId(
      prefix: 'pr',
      sourceId: redemptionId,
      operation: consumptionOperationReturn,
    );
  }

  static String bookingAddonDeductId(String bookingId) {
    return consumptionId(
      prefix: 'ba',
      sourceId: bookingId,
      operation: consumptionOperationDeduct,
    );
  }

  static String bookingAddonReturnId(String bookingId) {
    return consumptionId(
      prefix: 'ba',
      sourceId: bookingId,
      operation: consumptionOperationReturn,
    );
  }

  static String bookingSupplyDeductId(String bookingId) {
    return consumptionId(
      prefix: 'bs',
      sourceId: bookingId,
      operation: consumptionOperationDeduct,
    );
  }

  static String bookingSupplyReturnId(String bookingId) {
    return consumptionId(
      prefix: 'bs',
      sourceId: bookingId,
      operation: consumptionOperationReturn,
    );
  }

  static String storeOrderDeductId(String orderId) {
    return consumptionId(
      prefix: 'so',
      sourceId: orderId,
      operation: consumptionOperationDeduct,
    );
  }

  static String storeOrderReturnId(String orderId) {
    return consumptionId(
      prefix: 'so',
      sourceId: orderId,
      operation: consumptionOperationReturn,
    );
  }

  static String movementDocId({
    required String consumptionId,
    required String inventoryItemId,
  }) {
    return '${consumptionId}_$inventoryItemId';
  }
}
