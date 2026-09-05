// 檔案名稱：lib/core/services/special_date_surcharge_service.dart
// 功能說明：管理店家的特殊日期加價設定，包含建立、修改、啟用、停用、刪除與查詢。
// 📅 特殊日期加價 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/special_date_surcharge_model.dart';

class SpecialDateSurchargeService {
  SpecialDateSurchargeService._();

  static final SpecialDateSurchargeService instance =
      SpecialDateSurchargeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _collection(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('special_date_surcharges');
  }

  /// 即時監聽店家全部特殊日期加價設定
  Stream<List<SpecialDateSurchargeModel>> streamSurcharges(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<SpecialDateSurchargeModel>>.value(
        const <SpecialDateSurchargeModel>[],
      );
    }

    return _collection(normalizedShopId).orderBy('startDate').snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      return snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return SpecialDateSurchargeModel.fromMap(
          id: document.id,
          data: document.data(),
        );
      }).toList();
    });
  }

  /// 一次取得目前啟用中的特殊日期加價
  Future<List<SpecialDateSurchargeModel>> getEnabledSurcharges(
    String shopId,
  ) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const <SpecialDateSurchargeModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection(
      normalizedShopId,
    ).where('enabled', isEqualTo: true).get();

    final List<SpecialDateSurchargeModel> items = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) {
      return SpecialDateSurchargeModel.fromMap(
        id: document.id,
        data: document.data(),
      );
    }).toList();

    items.sort((
      SpecialDateSurchargeModel first,
      SpecialDateSurchargeModel second,
    ) {
      return first.startDate.compareTo(second.startDate);
    });

    return items;
  }

  /// 建立特殊日期加價
  Future<String> createSurcharge({
    required String shopId,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required int amountPerNight,
    required bool enabled,
    required bool allowCampaignDiscount,
    required bool allowCoupon,
    required List<String> roomTypeIds,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedName = name.trim();

    _validate(
      shopId: normalizedShopId,
      name: normalizedName,
      startDate: startDate,
      endDate: endDate,
      amountPerNight: amountPerNight,
    );

    final DocumentReference<Map<String, dynamic>> reference = _collection(
      normalizedShopId,
    ).doc();

    final DateTime now = DateTime.now();

    final SpecialDateSurchargeModel model = SpecialDateSurchargeModel(
      id: reference.id,
      shopId: normalizedShopId,
      name: normalizedName,
      description: description.trim(),
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: DateTime(endDate.year, endDate.month, endDate.day),
      amountPerNight: amountPerNight,
      enabled: enabled,
      allowCampaignDiscount: allowCampaignDiscount,
      allowCoupon: allowCoupon,
      roomTypeIds: roomTypeIds,
      createdBy: _auth.currentUser?.uid ?? '',
      createdAt: now,
      updatedAt: now,
    );

    await reference.set(model.toMap());

    return reference.id;
  }

  /// 更新特殊日期加價
  Future<void> updateSurcharge({
    required String shopId,
    required String surchargeId,
    required String name,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required int amountPerNight,
    required bool enabled,
    required bool allowCampaignDiscount,
    required bool allowCoupon,
    required List<String> roomTypeIds,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedSurchargeId = surchargeId.trim();
    final String normalizedName = name.trim();

    if (normalizedSurchargeId.isEmpty) {
      throw ArgumentError('特殊日期加價 ID 不可為空');
    }

    _validate(
      shopId: normalizedShopId,
      name: normalizedName,
      startDate: startDate,
      endDate: endDate,
      amountPerNight: amountPerNight,
    );

    await _collection(
      normalizedShopId,
    ).doc(normalizedSurchargeId).update(<String, dynamic>{
      'name': normalizedName,
      'description': description.trim(),
      'startDate': Timestamp.fromDate(
        DateTime(startDate.year, startDate.month, startDate.day),
      ),
      'endDate': Timestamp.fromDate(
        DateTime(endDate.year, endDate.month, endDate.day),
      ),
      'amountPerNight': amountPerNight,
      'enabled': enabled,
      'allowCampaignDiscount': allowCampaignDiscount,
      'allowCoupon': allowCoupon,
      'roomTypeIds': roomTypeIds,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 單獨切換啟用狀態
  Future<void> setEnabled({
    required String shopId,
    required String surchargeId,
    required bool enabled,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedSurchargeId = surchargeId.trim();

    if (normalizedShopId.isEmpty || normalizedSurchargeId.isEmpty) {
      throw ArgumentError('店家 ID 或特殊日期加價 ID 不可為空');
    }

    await _collection(normalizedShopId).doc(normalizedSurchargeId).update(
      <String, dynamic>{
        'enabled': enabled,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      },
    );
  }

  /// 刪除特殊日期加價設定
  Future<void> deleteSurcharge({
    required String shopId,
    required String surchargeId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedSurchargeId = surchargeId.trim();

    if (normalizedShopId.isEmpty || normalizedSurchargeId.isEmpty) {
      throw ArgumentError('店家 ID 或特殊日期加價 ID 不可為空');
    }

    await _collection(normalizedShopId).doc(normalizedSurchargeId).delete();
  }

  void _validate({
    required String shopId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int amountPerNight,
  }) {
    if (shopId.isEmpty) {
      throw ArgumentError('店家 ID 不可為空');
    }

    if (name.isEmpty) {
      throw ArgumentError('請輸入特殊日期加價名稱');
    }

    final DateTime normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final DateTime normalizedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError('結束日期不可早於開始日期');
    }

    if (amountPerNight <= 0) {
      throw ArgumentError('每晚加價金額必須大於 0');
    }
  }
}
