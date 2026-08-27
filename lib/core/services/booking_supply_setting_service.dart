// lib/core/services/booking_supply_setting_service.dart
// 🧹 住宿耗材設定 Service
// 功能：讀取與儲存店家的住宿必要用品。可純手動記錄，或綁定中央庫存於入住時扣除。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/inventory_constants.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/models/booking_supply_setting_model.dart';

class BookingSupplySettingService {
  BookingSupplySettingService._();

  static final BookingSupplySettingService instance =
      BookingSupplySettingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _collection(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId.trim())
        .collection(InventoryConstants.bookingSupplySettingsCollection);
  }

  Stream<List<BookingSupplySettingModel>> streamSettings(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<BookingSupplySettingModel>>.value(
        const <BookingSupplySettingModel>[],
      );
    }

    return _collection(normalizedShopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<BookingSupplySettingModel> settings = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return BookingSupplySettingModel.fromMap(
          id: document.id,
          data: document.data(),
        );
      }).toList();

      settings.sort((BookingSupplySettingModel a, BookingSupplySettingModel b) {
        return a.name.compareTo(b.name);
      });

      return settings;
    });
  }

  Future<List<BookingSupplySettingModel>> getSettings(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const <BookingSupplySettingModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection(
      normalizedShopId,
    ).get();

    return snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return BookingSupplySettingModel.fromMap(
            id: document.id,
            data: document.data(),
          );
        })
        .toList();
  }

  Future<String> saveSetting({
    required String shopId,
    String? settingId,
    required String name,
    required bool useInventory,
    String inventoryItemId = '',
    String inventoryItemName = '',
    String unit = '',
    required num quantityPerUnit,
    required BookingSupplyDeductionMode deductionMode,
    bool enabled = true,
    String note = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedName = name.trim();
    final String operatorUid = _auth.currentUser?.uid ?? '';

    if (normalizedShopId.isEmpty) {
      throw const InventoryException('找不到店家資料');
    }

    if (normalizedName.isEmpty) {
      throw const InventoryException('請輸入用品名稱');
    }

    if (quantityPerUnit <= 0) {
      throw const InventoryException('扣除數量必須大於 0');
    }

    if (useInventory && inventoryItemId.trim().isEmpty) {
      throw const InventoryException('請選擇中央庫存品項');
    }

    final DateTime now = DateTime.now();
    final DocumentReference<Map<String, dynamic>> reference = settingId == null
        ? _collection(normalizedShopId).doc()
        : _collection(normalizedShopId).doc(settingId.trim());

    final BookingSupplySettingModel setting = BookingSupplySettingModel(
      id: reference.id,
      shopId: normalizedShopId,
      name: normalizedName,
      useInventory: useInventory,
      inventoryItemId: useInventory ? inventoryItemId.trim() : '',
      inventoryItemName: useInventory ? inventoryItemName.trim() : '',
      unit: unit.trim(),
      quantityPerUnit: quantityPerUnit,
      deductionMode: deductionMode,
      enabled: enabled,
      note: note.trim(),
      createdBy: operatorUid,
      updatedBy: operatorUid,
      createdAt: now,
      updatedAt: now,
    );

    final Map<String, dynamic> data = setting.toMap();

    if (settingId != null && settingId.trim().isNotEmpty) {
      data.remove('createdAt');
      data.remove('createdBy');
      await reference.set(data, SetOptions(merge: true));
    } else {
      await reference.set(data);
    }

    return reference.id;
  }
}
