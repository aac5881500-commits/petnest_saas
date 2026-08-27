// lib/core/services/inventory_stock_service.dart
// 📦 中央庫存異動 Service
// 功能：所有 currentStock 變動都在 Firestore Transaction 中同時寫入異動流水。
// 自動扣庫存與返還使用確定性 consumption ID，防止重複扣除或重複補庫存。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/booking_supply_setting_model.dart';
import 'package:petnest_saas/core/models/inventory_binding_model.dart';
import 'package:petnest_saas/core/models/inventory_consumption_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/services/booking_supply_setting_service.dart';
import 'package:petnest_saas/core/services/inventory_service.dart';

class InventoryStockLine {
  const InventoryStockLine({
    required this.inventoryItemId,
    required this.quantityChange,
    this.unitCost = 0,
    this.reason = '',
    this.note = '',
    this.sourceSubId = '',
  });

  final String inventoryItemId;
  final num quantityChange;
  final num unitCost;
  final String reason;
  final String note;
  final String sourceSubId;
}

class PreparedStockLine {
  const PreparedStockLine({
    required this.item,
    required this.itemReference,
    required this.movementReference,
    required this.quantityChange,
    required this.stockBefore,
    required this.stockAfter,
    required this.reason,
    required this.note,
    required this.sourceSubId,
  });

  final InventoryItemModel item;
  final DocumentReference<Map<String, dynamic>> itemReference;
  final DocumentReference<Map<String, dynamic>> movementReference;
  final num quantityChange;
  final num stockBefore;
  final num stockAfter;
  final String reason;
  final String note;
  final String sourceSubId;
}

class PreparedStockConsumption {
  const PreparedStockConsumption({
    required this.skip,
    required this.consumptionReference,
    required this.lines,
    required this.sourceType,
    required this.sourceId,
    required this.operation,
    required this.type,
    required this.note,
  });

  final bool skip;
  final DocumentReference<Map<String, dynamic>> consumptionReference;
  final List<PreparedStockLine> lines;
  final InventorySourceType sourceType;
  final String sourceId;
  final String operation;
  final InventoryMovementType type;
  final String note;
}

class InventoryStockService {
  InventoryStockService._();

  static final InventoryStockService instance = InventoryStockService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final InventoryService _inventory = InventoryService.instance;

  Future<void> receiveStock({
    required String shopId,
    required String itemId,
    required num quantity,
    required num unitCost,
    required DateTime receivedAt,
    String batchNo = '',
    DateTime? expiryDate,
    String supplier = '',
    String note = '',
  }) async {
    if (quantity <= 0) {
      throw const InventoryException('進貨數量必須大於 0');
    }

    if (unitCost < 0) {
      throw const InventoryException('進貨單價不可為負數');
    }

    final String operatorUid = _requireUid();
    final num totalCost = InventoryConstants.batchTotalCost(
      quantity: quantity,
      unitCost: unitCost,
    );
    final DateTime now = DateTime.now();

    final DocumentReference<Map<String, dynamic>> itemReference = _inventory
        .itemsRef(shopId)
        .doc(itemId.trim());

    final DocumentReference<Map<String, dynamic>> batchReference = _inventory
        .batchesRef(shopId: shopId, itemId: itemId)
        .doc();

    final DocumentReference<Map<String, dynamic>> movementReference =
        _inventory.movementsRef(shopId: shopId, itemId: itemId).doc();

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> itemSnapshot =
          await transaction.get(itemReference);

      final InventoryItemModel item = _requireItem(
        snapshot: itemSnapshot,
        requireEnabled: true,
      );

      _assertQuantityAllowed(item: item, quantity: quantity);

      final num stockBefore = item.currentStock;
      final num stockAfter = InventoryConstants.roundQuantity(
        stockBefore + quantity,
      );
      final num nextEstimatedCost = InventoryConstants.roundMoney(
        item.estimatedStockCost + totalCost,
      );
      final num nextAverage = InventoryConstants.weightedAverageFromCost(
        estimatedStockCost: nextEstimatedCost,
        currentStock: stockAfter,
      );
      final DateTime? nearestExpiry = _nearestExpiry(
        current: item.nearestExpiryDate,
        incoming: expiryDate,
      );

      transaction.update(itemReference, <String, dynamic>{
        'currentStock': stockAfter,
        'lastPurchaseUnitCost': InventoryConstants.roundMoney(unitCost),
        'weightedAverageCost': nextAverage,
        'estimatedStockCost': nextEstimatedCost,
        'nearestExpiryDate': nearestExpiry == null
            ? item.nearestExpiryDate == null
                  ? null
                  : Timestamp.fromDate(item.nearestExpiryDate!)
            : Timestamp.fromDate(nearestExpiry),
        'updatedBy': operatorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(batchReference, <String, dynamic>{
        'shopId': shopId.trim(),
        'inventoryItemId': item.id,
        'batchNo': batchNo.trim(),
        'quantityReceived': quantity,
        'remainingQuantity': quantity,
        'unitCost': InventoryConstants.roundMoney(unitCost),
        'totalCost': totalCost,
        'receivedAt': Timestamp.fromDate(receivedAt),
        'expiryDate': expiryDate == null ? null : Timestamp.fromDate(expiryDate),
        'supplier': supplier.trim(),
        'note': note.trim(),
        'createdBy': operatorUid,
        'createdAt': Timestamp.fromDate(now),
      });

      transaction.set(movementReference, <String, dynamic>{
        'shopId': shopId.trim(),
        'inventoryItemId': item.id,
        'type': InventoryConstants.movementTypeValue(
          InventoryMovementType.purchase,
        ),
        'quantityChange': quantity,
        'stockBefore': stockBefore,
        'stockAfter': stockAfter,
        'sourceType': InventoryConstants.sourceTypeValue(
          InventorySourceType.purchase,
        ),
        'sourceId': batchReference.id,
        'sourceSubId': '',
        'unitCost': InventoryConstants.roundMoney(unitCost),
        'reason': '進貨',
        'note': note.trim(),
        'createdBy': operatorUid,
        'itemNameSnapshot': item.name,
        'unitSnapshot': item.unit,
        'createdAt': Timestamp.fromDate(now),
      });
    });
  }

  Future<void> manualOutbound({
    required String shopId,
    required String itemId,
    required num quantity,
    required InventoryOutboundReason reason,
    String note = '',
  }) async {
    if (quantity <= 0) {
      throw const InventoryException('出庫數量必須大於 0');
    }

    await _applyDirectChange(
      shopId: shopId,
      itemId: itemId,
      quantityChange: -quantity,
      type: InventoryMovementType.manualOutbound,
      sourceType: InventorySourceType.manualOutbound,
      sourceId: itemId,
      reason: InventoryConstants.outboundReasonLabel(reason),
      note: note,
      requireEnabled: true,
    );
  }

  Future<void> adjustStock({
    required String shopId,
    required String itemId,
    required num countedStock,
    String note = '',
  }) async {
    if (countedStock < 0) {
      throw const InventoryException('盤點數量不可為負數');
    }

    final String operatorUid = _requireUid();
    final DateTime now = DateTime.now();
    final DocumentReference<Map<String, dynamic>> itemReference = _inventory
        .itemsRef(shopId)
        .doc(itemId.trim());
    final DocumentReference<Map<String, dynamic>> movementReference =
        _inventory.movementsRef(shopId: shopId, itemId: itemId).doc();

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> itemSnapshot =
          await transaction.get(itemReference);

      final InventoryItemModel item = _requireItem(
        snapshot: itemSnapshot,
        requireEnabled: false,
      );

      _assertQuantityAllowed(item: item, quantity: countedStock);

      final num stockBefore = item.currentStock;
      final num stockAfter = InventoryConstants.roundQuantity(countedStock);
      final num quantityChange = InventoryConstants.roundQuantity(
        stockAfter - stockBefore,
      );

      if (quantityChange == 0) {
        throw const InventoryException('盤點數量與系統庫存相同，不需調整');
      }

      final ({num estimatedStockCost, num weightedAverageCost}) nextCost =
          _costAfterStockChange(item: item, stockAfter: stockAfter);

      transaction.update(itemReference, <String, dynamic>{
        'currentStock': stockAfter,
        'estimatedStockCost': nextCost.estimatedStockCost,
        'weightedAverageCost': nextCost.weightedAverageCost,
        'updatedBy': operatorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(movementReference, <String, dynamic>{
        'shopId': shopId.trim(),
        'inventoryItemId': item.id,
        'type': InventoryConstants.movementTypeValue(
          InventoryMovementType.adjustment,
        ),
        'quantityChange': quantityChange,
        'stockBefore': stockBefore,
        'stockAfter': stockAfter,
        'sourceType': InventoryConstants.sourceTypeValue(
          InventorySourceType.adjustment,
        ),
        'sourceId': item.id,
        'sourceSubId': '',
        'unitCost': item.weightedAverageCost,
        'reason': '盤點調整',
        'note': note.trim(),
        'createdBy': operatorUid,
        'itemNameSnapshot': item.name,
        'unitSnapshot': item.unit,
        'createdAt': Timestamp.fromDate(now),
      });
    });
  }

  Future<void> consumeBookingAddons({
    required String shopId,
    required String bookingId,
    Map<String, dynamic>? bookingData,
  }) async {
    final Map<String, dynamic> data =
        bookingData ?? await _getBookingData(bookingId);

    if (data['status']?.toString() == 'cancelled') {
      return;
    }

    final List<InventoryStockLine> lines = _addonLinesFromBooking(data);

    if (lines.isEmpty) {
      return;
    }

    await applyConsumption(
      shopId: shopId,
      consumptionId: InventoryConstants.bookingAddonDeductId(bookingId),
      sourceType: InventorySourceType.addon,
      sourceId: bookingId,
      operation: InventoryConstants.consumptionOperationDeduct,
      type: InventoryMovementType.addon,
      lines: lines,
      note: '預約加購扣庫存',
    );
  }

  Future<void> returnBookingAddons({
    required String shopId,
    required String bookingId,
  }) async {
    await _returnByDeductConsumption(
      shopId: shopId,
      deductConsumptionId: InventoryConstants.bookingAddonDeductId(bookingId),
      returnConsumptionId: InventoryConstants.bookingAddonReturnId(bookingId),
      sourceType: InventorySourceType.returnStock,
      sourceId: bookingId,
      type: InventoryMovementType.returnStock,
      note: '取消預約返還加購庫存',
    );
  }

  Future<void> consumeBookingSupplies({
    required String shopId,
    required String bookingId,
    Map<String, dynamic>? bookingData,
  }) async {
    final Map<String, dynamic> data =
        bookingData ?? await _getBookingData(bookingId);

    if (data['status']?.toString() == 'cancelled') {
      return;
    }

    final List<BookingSupplySettingModel> settings =
        await BookingSupplySettingService.instance.getSettings(shopId);

    final List<InventoryStockLine> lines = _supplyLinesFromBooking(
      booking: data,
      settings: settings,
    );

    if (lines.isEmpty) {
      return;
    }

    await applyConsumption(
      shopId: shopId,
      consumptionId: InventoryConstants.bookingSupplyDeductId(bookingId),
      sourceType: InventorySourceType.bookingSupply,
      sourceId: bookingId,
      operation: InventoryConstants.consumptionOperationDeduct,
      type: InventoryMovementType.bookingSupply,
      lines: lines,
      note: '入住扣除住宿耗材',
    );
  }

  Future<void> returnBookingSupplies({
    required String shopId,
    required String bookingId,
  }) async {
    await _returnByDeductConsumption(
      shopId: shopId,
      deductConsumptionId: InventoryConstants.bookingSupplyDeductId(bookingId),
      returnConsumptionId: InventoryConstants.bookingSupplyReturnId(bookingId),
      sourceType: InventorySourceType.returnStock,
      sourceId: bookingId,
      type: InventoryMovementType.returnStock,
      note: '取消訂單返還住宿耗材',
    );
  }

  Future<PreparedStockConsumption> preparePointRedemptionDeduct({
    required Transaction transaction,
    required String shopId,
    required String redemptionId,
    required String inventoryItemId,
    required num quantity,
    String itemName = '',
    String note = '',
  }) {
    return prepareConsumption(
      transaction: transaction,
      shopId: shopId,
      consumptionId: InventoryConstants.redemptionDeductId(redemptionId),
      sourceType: InventorySourceType.pointRedemption,
      sourceId: redemptionId,
      operation: InventoryConstants.consumptionOperationDeduct,
      type: InventoryMovementType.pointRedemption,
      lines: <InventoryStockLine>[
        InventoryStockLine(
          inventoryItemId: inventoryItemId,
          quantityChange: -quantity,
          note: note,
          reason: '點數兌換${itemName.isEmpty ? '' : '「$itemName」'}',
        ),
      ],
      note: note,
    );
  }

  Future<PreparedStockConsumption> preparePointRedemptionReturn({
    required Transaction transaction,
    required String shopId,
    required String redemptionId,
  }) {
    return prepareReturn(
      transaction: transaction,
      shopId: shopId,
      deductConsumptionId: InventoryConstants.redemptionDeductId(redemptionId),
      returnConsumptionId: InventoryConstants.redemptionReturnId(redemptionId),
      sourceType: InventorySourceType.returnStock,
      sourceId: redemptionId,
      type: InventoryMovementType.returnStock,
      note: '取消點數兌換返還庫存',
    );
  }

  Future<void> applyConsumption({
    required String shopId,
    required String consumptionId,
    required InventorySourceType sourceType,
    required String sourceId,
    required String operation,
    required InventoryMovementType type,
    required List<InventoryStockLine> lines,
    String note = '',
    Transaction? transaction,
  }) async {
    final List<InventoryStockLine> merged = _mergeLines(lines);

    if (merged.isEmpty) {
      return;
    }

    if (transaction != null) {
      final PreparedStockConsumption prepared = await prepareConsumption(
        transaction: transaction,
        shopId: shopId,
        consumptionId: consumptionId,
        sourceType: sourceType,
        sourceId: sourceId,
        operation: operation,
        type: type,
        lines: merged,
        note: note,
      );
      commitPreparedConsumption(
        transaction: transaction,
        prepared: prepared,
      );
      return;
    }

    await _firestore.runTransaction((Transaction inner) async {
      final PreparedStockConsumption prepared = await prepareConsumption(
        transaction: inner,
        shopId: shopId,
        consumptionId: consumptionId,
        sourceType: sourceType,
        sourceId: sourceId,
        operation: operation,
        type: type,
        lines: merged,
        note: note,
      );
      commitPreparedConsumption(transaction: inner, prepared: prepared);
    });
  }

  Future<PreparedStockConsumption> prepareConsumption({
    required Transaction transaction,
    required String shopId,
    required String consumptionId,
    required InventorySourceType sourceType,
    required String sourceId,
    required String operation,
    required InventoryMovementType type,
    required List<InventoryStockLine> lines,
    String note = '',
  }) async {
    final List<InventoryStockLine> merged = _mergeLines(lines);
    final DocumentReference<Map<String, dynamic>> consumptionReference =
        _inventory.consumptionsRef(shopId).doc(consumptionId);

    final DocumentSnapshot<Map<String, dynamic>> consumptionSnapshot =
        await transaction.get(consumptionReference);

    if (consumptionSnapshot.exists || merged.isEmpty) {
      return PreparedStockConsumption(
        skip: true,
        consumptionReference: consumptionReference,
        lines: const <PreparedStockLine>[],
        sourceType: sourceType,
        sourceId: sourceId,
        operation: operation,
        type: type,
        note: note,
      );
    }

    final bool isReturn =
        operation == InventoryConstants.consumptionOperationReturn;
    final List<PreparedStockLine> preparedLines = <PreparedStockLine>[];

    for (final InventoryStockLine line in merged) {
      final DocumentReference<Map<String, dynamic>> itemReference = _inventory
          .itemsRef(shopId)
          .doc(line.inventoryItemId);
      final DocumentSnapshot<Map<String, dynamic>> itemSnapshot =
          await transaction.get(itemReference);

      final InventoryItemModel item = _requireItem(
        snapshot: itemSnapshot,
        requireEnabled: !isReturn,
      );

      final num quantity = line.quantityChange.abs();
      _assertQuantityAllowed(item: item, quantity: quantity);

      final num stockBefore = item.currentStock;
      final num stockAfter = InventoryConstants.roundQuantity(
        stockBefore + line.quantityChange,
      );

      if (stockAfter < 0) {
        throw InventoryException(
          '庫存不足，目前剩餘 ${InventoryConstants.formatQuantity(stockBefore)} ${item.unit}',
        );
      }

      preparedLines.add(
        PreparedStockLine(
          item: item,
          itemReference: itemReference,
          movementReference: _inventory
              .movementsRef(shopId: shopId, itemId: item.id)
              .doc(
                InventoryConstants.movementDocId(
                  consumptionId: consumptionId,
                  inventoryItemId: item.id,
                ),
              ),
          quantityChange: line.quantityChange,
          stockBefore: stockBefore,
          stockAfter: stockAfter,
          reason: line.reason,
          note: line.note.trim().isEmpty ? note : line.note.trim(),
          sourceSubId: line.sourceSubId,
        ),
      );
    }

    return PreparedStockConsumption(
      skip: false,
      consumptionReference: consumptionReference,
      lines: preparedLines,
      sourceType: sourceType,
      sourceId: sourceId,
      operation: operation,
      type: type,
      note: note,
    );
  }

  Future<PreparedStockConsumption> prepareReturn({
    required Transaction transaction,
    required String shopId,
    required String deductConsumptionId,
    required String returnConsumptionId,
    required InventorySourceType sourceType,
    required String sourceId,
    required InventoryMovementType type,
    required String note,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> returnSnapshot =
        await transaction.get(
          _inventory.consumptionsRef(shopId).doc(returnConsumptionId),
        );

    if (returnSnapshot.exists) {
      return PreparedStockConsumption(
        skip: true,
        consumptionReference: returnSnapshot.reference,
        lines: const <PreparedStockLine>[],
        sourceType: sourceType,
        sourceId: sourceId,
        operation: InventoryConstants.consumptionOperationReturn,
        type: type,
        note: note,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> deductSnapshot =
        await transaction.get(
          _inventory.consumptionsRef(shopId).doc(deductConsumptionId),
        );

    if (!deductSnapshot.exists || deductSnapshot.data() == null) {
      return PreparedStockConsumption(
        skip: true,
        consumptionReference: _inventory
            .consumptionsRef(shopId)
            .doc(returnConsumptionId),
        lines: const <PreparedStockLine>[],
        sourceType: sourceType,
        sourceId: sourceId,
        operation: InventoryConstants.consumptionOperationReturn,
        type: type,
        note: note,
      );
    }

    final InventoryConsumptionModel deduct = InventoryConsumptionModel.fromMap(
      id: deductSnapshot.id,
      data: deductSnapshot.data()!,
    );

    return prepareConsumption(
      transaction: transaction,
      shopId: shopId,
      consumptionId: returnConsumptionId,
      sourceType: sourceType,
      sourceId: sourceId,
      operation: InventoryConstants.consumptionOperationReturn,
      type: type,
      lines: deduct.lines.map((InventoryConsumptionLine line) {
        return InventoryStockLine(
          inventoryItemId: line.inventoryItemId,
          quantityChange: line.quantity,
          reason: '取消返還',
          note: note,
        );
      }).toList(),
      note: note,
    );
  }

  void commitPreparedConsumption({
    required Transaction transaction,
    required PreparedStockConsumption prepared,
  }) {
    if (prepared.skip) {
      return;
    }

    final String operatorUid = _auth.currentUser?.uid ?? '';
    final DateTime now = DateTime.now();
    final List<InventoryConsumptionLine> consumptionLines =
        <InventoryConsumptionLine>[];

    for (final PreparedStockLine line in prepared.lines) {
      final ({num estimatedStockCost, num weightedAverageCost}) nextCost =
          _costAfterStockChange(item: line.item, stockAfter: line.stockAfter);

      transaction.update(line.itemReference, <String, dynamic>{
        'currentStock': line.stockAfter,
        'estimatedStockCost': nextCost.estimatedStockCost,
        'weightedAverageCost': nextCost.weightedAverageCost,
        'updatedBy': operatorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(line.movementReference, <String, dynamic>{
        'shopId': line.item.shopId,
        'inventoryItemId': line.item.id,
        'type': InventoryConstants.movementTypeValue(prepared.type),
        'quantityChange': line.quantityChange,
        'stockBefore': line.stockBefore,
        'stockAfter': line.stockAfter,
        'sourceType': InventoryConstants.sourceTypeValue(prepared.sourceType),
        'sourceId': prepared.sourceId,
        'sourceSubId': line.sourceSubId,
        'unitCost': line.item.weightedAverageCost,
        'reason': line.reason,
        'note': line.note,
        'createdBy': operatorUid,
        'itemNameSnapshot': line.item.name,
        'unitSnapshot': line.item.unit,
        'createdAt': Timestamp.fromDate(now),
      });

      consumptionLines.add(
        InventoryConsumptionLine(
          inventoryItemId: line.item.id,
          quantity: line.quantityChange.abs(),
          movementId: line.movementReference.id,
          stockBefore: line.stockBefore,
          stockAfter: line.stockAfter,
          itemName: line.item.name,
          unit: line.item.unit,
        ),
      );
    }

    transaction.set(
      prepared.consumptionReference,
      InventoryConsumptionModel(
        id: prepared.consumptionReference.id,
        shopId: prepared.lines.isEmpty ? '' : prepared.lines.first.item.shopId,
        sourceType: InventoryConstants.sourceTypeValue(prepared.sourceType),
        sourceId: prepared.sourceId,
        operation: prepared.operation,
        status: InventoryConstants.consumptionStatusCompleted,
        lines: consumptionLines,
        createdBy: operatorUid,
        note: prepared.note,
        createdAt: now,
      ).toMap(),
    );
  }

  Future<void> _returnByDeductConsumption({
    required String shopId,
    required String deductConsumptionId,
    required String returnConsumptionId,
    required InventorySourceType sourceType,
    required String sourceId,
    required InventoryMovementType type,
    required String note,
  }) async {
    await _firestore.runTransaction((Transaction inner) async {
      final PreparedStockConsumption prepared = await prepareReturn(
        transaction: inner,
        shopId: shopId,
        deductConsumptionId: deductConsumptionId,
        returnConsumptionId: returnConsumptionId,
        sourceType: sourceType,
        sourceId: sourceId,
        type: type,
        note: note,
      );
      commitPreparedConsumption(transaction: inner, prepared: prepared);
    });
  }

  Future<void> _applyDirectChange({
    required String shopId,
    required String itemId,
    required num quantityChange,
    required InventoryMovementType type,
    required InventorySourceType sourceType,
    required String sourceId,
    required String reason,
    required String note,
    required bool requireEnabled,
  }) async {
    final String operatorUid = _requireUid();
    final DateTime now = DateTime.now();
    final DocumentReference<Map<String, dynamic>> itemReference = _inventory
        .itemsRef(shopId)
        .doc(itemId.trim());
    final DocumentReference<Map<String, dynamic>> movementReference =
        _inventory.movementsRef(shopId: shopId, itemId: itemId).doc();

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> itemSnapshot =
          await transaction.get(itemReference);

      final InventoryItemModel item = _requireItem(
        snapshot: itemSnapshot,
        requireEnabled: requireEnabled,
      );

      _assertQuantityAllowed(item: item, quantity: quantityChange.abs());

      final num stockBefore = item.currentStock;
      final num stockAfter = InventoryConstants.roundQuantity(
        stockBefore + quantityChange,
      );

      if (stockAfter < 0) {
        throw InventoryException(
          '庫存不足，目前剩餘 ${InventoryConstants.formatQuantity(stockBefore)} ${item.unit}',
        );
      }

      final ({num estimatedStockCost, num weightedAverageCost}) nextCost =
          _costAfterStockChange(item: item, stockAfter: stockAfter);

      transaction.update(itemReference, <String, dynamic>{
        'currentStock': stockAfter,
        'estimatedStockCost': nextCost.estimatedStockCost,
        'weightedAverageCost': nextCost.weightedAverageCost,
        'updatedBy': operatorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(movementReference, <String, dynamic>{
        'shopId': shopId.trim(),
        'inventoryItemId': item.id,
        'type': InventoryConstants.movementTypeValue(type),
        'quantityChange': quantityChange,
        'stockBefore': stockBefore,
        'stockAfter': stockAfter,
        'sourceType': InventoryConstants.sourceTypeValue(sourceType),
        'sourceId': sourceId,
        'sourceSubId': '',
        'unitCost': item.weightedAverageCost,
        'reason': reason,
        'note': note.trim(),
        'createdBy': operatorUid,
        'itemNameSnapshot': item.name,
        'unitSnapshot': item.unit,
        'createdAt': Timestamp.fromDate(now),
      });
    });
  }

  List<InventoryStockLine> _addonLinesFromBooking(Map<String, dynamic> booking) {
    final Object? rawAddons = booking['addons'];
    if (rawAddons is! List) {
      return const <InventoryStockLine>[];
    }

    final List<InventoryStockLine> lines = <InventoryStockLine>[];

    for (final Object? rawAddon in rawAddons) {
      if (rawAddon is! Map) {
        continue;
      }

      final Map<String, dynamic> addon = Map<String, dynamic>.from(rawAddon);

      if (addon['useInventory'] != true) {
        continue;
      }

      final List<InventoryBindingModel> bindings =
          InventoryBindingModel.listFromValue(addon['inventoryBindings']);

      if (bindings.isEmpty) {
        continue;
      }

      final num count = _addonPurchaseCount(addon);

      for (final InventoryBindingModel binding in bindings) {
        final num quantity = InventoryConstants.roundQuantity(
          binding.quantityPerUnit * count,
        );

        if (quantity <= 0) {
          continue;
        }

        lines.add(
          InventoryStockLine(
            inventoryItemId: binding.inventoryItemId,
            quantityChange: -quantity,
            reason: '加購「${addon['name'] ?? ''}」',
            sourceSubId: (addon['id'] ?? addon['serviceId'] ?? '').toString(),
          ),
        );
      }
    }

    return lines;
  }

  num _addonPurchaseCount(Map<String, dynamic> addon) {
    final String type = (addon['type'] ?? '').toString();

    if (type == 'daily_timed' || type == 'custom') {
      final num count = addon['count'] is num
          ? addon['count'] as num
          : num.tryParse(addon['count']?.toString() ?? '') ?? 1;
      return count <= 0 ? 1 : count;
    }

    final num count = addon['count'] is num
        ? addon['count'] as num
        : num.tryParse(addon['count']?.toString() ?? '') ?? 1;

    return count <= 0 ? 1 : count;
  }

  List<InventoryStockLine> _supplyLinesFromBooking({
    required Map<String, dynamic> booking,
    required List<BookingSupplySettingModel> settings,
  }) {
    final int nights = _positiveInt(booking['nights'], fallback: 1);
    final int petCount = _bookingPetCount(booking);
    final int roomCount = 1;

    final List<InventoryStockLine> lines = <InventoryStockLine>[];

    for (final BookingSupplySettingModel setting in settings) {
      if (!setting.shouldDeductInventory) {
        continue;
      }

      num multiplier;

      switch (setting.deductionMode) {
        case BookingSupplyDeductionMode.perRoomPerNight:
          multiplier = roomCount * nights;
          break;
        case BookingSupplyDeductionMode.perRoomPerStay:
          multiplier = roomCount;
          break;
        case BookingSupplyDeductionMode.perPetPerNight:
          multiplier = petCount * nights;
          break;
        case BookingSupplyDeductionMode.perPetPerStay:
          multiplier = petCount;
          break;
      }

      final num quantity = InventoryConstants.roundQuantity(
        setting.quantityPerUnit * multiplier,
      );

      if (quantity <= 0) {
        continue;
      }

      lines.add(
        InventoryStockLine(
          inventoryItemId: setting.inventoryItemId,
          quantityChange: -quantity,
          reason: '住宿耗材「${setting.name}」',
          sourceSubId: setting.id,
        ),
      );
    }

    return lines;
  }

  int _bookingPetCount(Map<String, dynamic> booking) {
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

  List<InventoryStockLine> _mergeLines(List<InventoryStockLine> lines) {
    final Map<String, InventoryStockLine> merged = <String, InventoryStockLine>{};

    for (final InventoryStockLine line in lines) {
      final String itemId = line.inventoryItemId.trim();
      if (itemId.isEmpty || line.quantityChange == 0) {
        continue;
      }

      final InventoryStockLine? existing = merged[itemId];
      if (existing == null) {
        merged[itemId] = line;
        continue;
      }

      merged[itemId] = InventoryStockLine(
        inventoryItemId: itemId,
        quantityChange: InventoryConstants.roundQuantity(
          existing.quantityChange + line.quantityChange,
        ),
        unitCost: line.unitCost,
        reason: existing.reason,
        note: existing.note,
        sourceSubId: existing.sourceSubId,
      );
    }

    return merged.values
        .where((InventoryStockLine line) => line.quantityChange != 0)
        .toList();
  }

  Future<Map<String, dynamic>> _getBookingData(String bookingId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('bookings')
        .doc(bookingId.trim())
        .get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const InventoryException('找不到訂單資料');
    }

    return data;
  }

  InventoryItemModel _requireItem({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required bool requireEnabled,
  }) {
    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const InventoryException('找不到庫存品項');
    }

    final InventoryItemModel item = InventoryItemModel.fromMap(
      id: snapshot.id,
      data: data,
    );

    if (requireEnabled && !item.enabled) {
      throw const InventoryException('此庫存品項已停用');
    }

    return item;
  }

  void _assertQuantityAllowed({
    required InventoryItemModel item,
    required num quantity,
  }) {
    if (quantity < 0) {
      throw const InventoryException('數量不可為負數');
    }

    if (!item.allowDecimal && quantity % 1 != 0) {
      throw InventoryException('「${item.name}」僅允許整數數量');
    }
  }

  ({num estimatedStockCost, num weightedAverageCost}) _costAfterStockChange({
    required InventoryItemModel item,
    required num stockAfter,
  }) {
    final num nextEstimatedCost = InventoryConstants.remainingStockCost(
      currentEstimatedCost: item.estimatedStockCost,
      stockBefore: item.currentStock,
      stockAfter: stockAfter,
      fallbackUnitCost: item.weightedAverageCost,
    );

    return (
      estimatedStockCost: nextEstimatedCost,
      weightedAverageCost: InventoryConstants.weightedAverageFromCost(
        estimatedStockCost: nextEstimatedCost,
        currentStock: stockAfter,
        fallbackUnitCost: item.weightedAverageCost,
      ),
    );
  }

  DateTime? _nearestExpiry({
    required DateTime? current,
    required DateTime? incoming,
  }) {
    if (incoming == null) {
      return current;
    }

    if (current == null) {
      return incoming;
    }

    return incoming.isBefore(current) ? incoming : current;
  }

  int _positiveInt(dynamic value, {required int fallback}) {
    if (value is int && value > 0) {
      return value;
    }

    if (value is num && value > 0) {
      return value.toInt();
    }

    return fallback;
  }

  String _requireUid() {
    final String uid = _auth.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      throw const InventoryException('請先登入');
    }

    return uid;
  }
}
