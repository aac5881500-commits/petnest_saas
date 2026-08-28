// lib/core/services/inventory_service.dart
// 📦 中央庫存主檔 Service
// 功能：提供庫存品項新增、編輯（不含直接改 currentStock）、停用、查詢與監聽。
// 實際庫存增減請走 InventoryStockService，以保證流水與數量同一 Transaction。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/inventory_batch_model.dart';
import 'package:petnest_saas/core/models/inventory_item_model.dart';
import 'package:petnest_saas/core/models/inventory_movement_model.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';

class InventoryService {
  InventoryService._();

  static final InventoryService instance = InventoryService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> itemsRef(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(InventoryConstants.itemsCollection);
  }

  CollectionReference<Map<String, dynamic>> batchesRef({
    required String shopId,
    required String itemId,
  }) {
    return itemsRef(shopId).doc(itemId).collection(InventoryConstants.batchesCollection);
  }

  CollectionReference<Map<String, dynamic>> movementsRef({
    required String shopId,
    required String itemId,
  }) {
    return itemsRef(shopId).doc(itemId).collection(InventoryConstants.movementsCollection);
  }

  CollectionReference<Map<String, dynamic>> consumptionsRef(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(InventoryConstants.consumptionsCollection);
  }

  Stream<List<InventoryItemModel>> streamItems(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<InventoryItemModel>>.value(const <InventoryItemModel>[]);
    }

    return itemsRef(normalizedShopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<InventoryItemModel> items = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return InventoryItemModel.fromMap(id: document.id, data: document.data());
      }).toList();

      items.sort((InventoryItemModel a, InventoryItemModel b) {
        return a.name.compareTo(b.name);
      });

      return items;
    });
  }

  Stream<List<InventoryItemModel>> streamEnabledItems(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<InventoryItemModel>>.value(const <InventoryItemModel>[]);
    }

    return itemsRef(normalizedShopId)
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<InventoryItemModel> items = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return InventoryItemModel.fromMap(id: document.id, data: document.data());
      }).toList();

      items.sort((InventoryItemModel a, InventoryItemModel b) {
        return a.name.compareTo(b.name);
      });

      return items;
    });
  }

  Future<InventoryItemModel?> getItem({
    required String shopId,
    required String itemId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedItemId = itemId.trim();

    if (normalizedShopId.isEmpty || normalizedItemId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await itemsRef(
      normalizedShopId,
    ).doc(normalizedItemId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return InventoryItemModel.fromMap(id: snapshot.id, data: data);
  }

  Stream<InventoryItemModel?> streamItem({
    required String shopId,
    required String itemId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedItemId = itemId.trim();

    if (normalizedShopId.isEmpty || normalizedItemId.isEmpty) {
      return Stream<InventoryItemModel?>.value(null);
    }

    return itemsRef(normalizedShopId).doc(normalizedItemId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return null;
      }

      return InventoryItemModel.fromMap(id: snapshot.id, data: data);
    });
  }

  Stream<List<InventoryBatchModel>> streamBatches({
    required String shopId,
    required String itemId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedItemId = itemId.trim();

    if (normalizedShopId.isEmpty || normalizedItemId.isEmpty) {
      return Stream<List<InventoryBatchModel>>.value(const <InventoryBatchModel>[]);
    }

    return batchesRef(shopId: normalizedShopId, itemId: normalizedItemId)
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            return InventoryBatchModel.fromMap(
              id: document.id,
              data: document.data(),
            );
          }).toList();
        });
  }

  Stream<List<InventoryMovementModel>> streamMovements({
    required String shopId,
    required String itemId,
    int limit = InventoryConstants.movementPageLimit,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedItemId = itemId.trim();

    if (normalizedShopId.isEmpty || normalizedItemId.isEmpty) {
      return Stream<List<InventoryMovementModel>>.value(
        const <InventoryMovementModel>[],
      );
    }

    return movementsRef(shopId: normalizedShopId, itemId: normalizedItemId)
        .orderBy('createdAt', descending: true)
        .limit(limit < 1 ? InventoryConstants.movementPageLimit : limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            return InventoryMovementModel.fromMap(
              id: document.id,
              data: document.data(),
            );
          }).toList();
        });
  }

  Future<String> createItem({
    required String shopId,
    required String name,
    String description = '',
    String category = '',
    String sku = '',
    String barcode = '',
    String unit = '個',
    num safetyStock = 0,
    bool allowDecimal = true,
    bool enabled = true,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedName = name.trim();
    final String operatorUid = _auth.currentUser?.uid ?? '';

    if (normalizedShopId.isEmpty) {
      throw const InventoryException('找不到店家資料');
    }

    if (normalizedName.isEmpty) {
      throw const InventoryException('請輸入庫存品項名稱');
    }

    if (safetyStock < 0) {
      throw const InventoryException('安全庫存不可為負數');
    }

    final DocumentReference<Map<String, dynamic>> itemReference = itemsRef(
      normalizedShopId,
    ).doc();

    await itemReference.set(<String, dynamic>{
      'shopId': normalizedShopId,
      'name': normalizedName,
      'description': description.trim(),
      'category': category.trim(),
      'sku': sku.trim(),
      'barcode': barcode.trim(),
      'unit': unit.trim().isEmpty ? '個' : unit.trim(),
      'currentStock': 0,
      'safetyStock': safetyStock,
      'allowDecimal': allowDecimal,
      'enabled': enabled,
      'lastPurchaseUnitCost': 0,
      'weightedAverageCost': 0,
      'estimatedStockCost': 0,
      'reservedQuantity': 0,
      'imageUrl': '',
      'imageStoragePath': '',
      'createdBy': operatorUid,
      'updatedBy': operatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logAction(
      shopId: normalizedShopId,
      targetId: itemReference.id,
      action: 'create_inventory_item',
      payload: <String, dynamic>{'name': normalizedName},
    );

    return itemReference.id;
  }

  Future<void> updateItem({
    required String shopId,
    required String itemId,
    required String name,
    String description = '',
    String category = '',
    String sku = '',
    String barcode = '',
    String unit = '個',
    num safetyStock = 0,
    bool allowDecimal = true,
    bool enabled = true,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedItemId = itemId.trim();
    final String normalizedName = name.trim();
    final String operatorUid = _auth.currentUser?.uid ?? '';

    if (normalizedShopId.isEmpty || normalizedItemId.isEmpty) {
      throw const InventoryException('找不到庫存品項');
    }

    if (normalizedName.isEmpty) {
      throw const InventoryException('請輸入庫存品項名稱');
    }

    if (safetyStock < 0) {
      throw const InventoryException('安全庫存不可為負數');
    }

    final DocumentReference<Map<String, dynamic>> itemReference = itemsRef(
      normalizedShopId,
    ).doc(normalizedItemId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(itemReference);

      if (!snapshot.exists || snapshot.data() == null) {
        throw const InventoryException('找不到庫存品項');
      }

      transaction.update(itemReference, <String, dynamic>{
        'name': normalizedName,
        'description': description.trim(),
        'category': category.trim(),
        'sku': sku.trim(),
        'barcode': barcode.trim(),
        'unit': unit.trim().isEmpty ? '個' : unit.trim(),
        'safetyStock': safetyStock,
        'allowDecimal': allowDecimal,
        'enabled': enabled,
        'updatedBy': operatorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _logAction(
      shopId: normalizedShopId,
      targetId: normalizedItemId,
      action: enabled ? 'update_inventory_item' : 'disable_inventory_item',
      payload: <String, dynamic>{'name': normalizedName, 'enabled': enabled},
    );
  }

  Future<void> updateItemCover({
    required String shopId,
    required String itemId,
    required String imageUrl,
    required String imageStoragePath,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedItemId = itemId.trim();

    if (normalizedShopId.isEmpty || normalizedItemId.isEmpty) {
      throw const InventoryException('找不到庫存品項');
    }

    await itemsRef(normalizedShopId).doc(normalizedItemId).update(
      <String, dynamic>{
        'imageUrl': imageUrl.trim(),
        'imageStoragePath': imageStoragePath.trim(),
        'updatedBy': _auth.currentUser?.uid ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> clearItemCover({
    required String shopId,
    required String itemId,
  }) async {
    await updateItemCover(
      shopId: shopId,
      itemId: itemId,
      imageUrl: '',
      imageStoragePath: '',
    );
  }

  Future<void> setItemEnabled({
    required String shopId,
    required String itemId,
    required bool enabled,
  }) async {
    final InventoryItemModel? item = await getItem(
      shopId: shopId,
      itemId: itemId,
    );

    if (item == null) {
      throw const InventoryException('找不到庫存品項');
    }

    await updateItem(
      shopId: shopId,
      itemId: itemId,
      name: item.name,
      description: item.description,
      category: item.category,
      sku: item.sku,
      barcode: item.barcode,
      unit: item.unit,
      safetyStock: item.safetyStock,
      allowDecimal: item.allowDecimal,
      enabled: enabled,
    );
  }

  Future<void> _logAction({
    required String shopId,
    required String targetId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await ActionLogService.instance.logAction(
        shopId: shopId,
        targetType: 'inventory_item',
        targetId: targetId,
        action: action,
        operatorUid: _auth.currentUser?.uid ?? '',
        operatorRole: 'staff',
        payload: payload,
      );
    } catch (_) {
      // 操作紀錄失敗不影響庫存主檔。
    }
  }
}
