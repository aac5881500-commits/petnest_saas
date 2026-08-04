// lib/core/services/discount_campaign_service.dart
// 🏷️ 優惠活動 Service
// 功能：管理店家的自動優惠活動，包含新增、修改、啟用、停用、刪除與查詢

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/discount_campaign_model.dart';

class DiscountCampaignService {
  DiscountCampaignService._();

  static final DiscountCampaignService instance = DiscountCampaignService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _campaignCollection(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('discount_campaigns');
  }

  /// 即時監聽店家全部優惠活動
  Stream<List<DiscountCampaignModel>> streamCampaigns(String shopId) {
    if (shopId.trim().isEmpty) {
      return Stream<List<DiscountCampaignModel>>.value(
        const <DiscountCampaignModel>[],
      );
    }

    return _campaignCollection(shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            return DiscountCampaignModel.fromMap(
              id: document.id,
              data: document.data(),
            );
          }).toList();
        });
  }

  /// 即時監聽目前啟用中的優惠活動
  Stream<List<DiscountCampaignModel>> streamEnabledCampaigns(String shopId) {
    if (shopId.trim().isEmpty) {
      return Stream<List<DiscountCampaignModel>>.value(
        const <DiscountCampaignModel>[],
      );
    }

    return _campaignCollection(shopId)
        .where('enabled', isEqualTo: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<DiscountCampaignModel> campaigns = snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            return DiscountCampaignModel.fromMap(
              id: document.id,
              data: document.data(),
            );
          }).toList();

          campaigns.sort((
            DiscountCampaignModel first,
            DiscountCampaignModel second,
          ) {
            return second.createdAt.compareTo(first.createdAt);
          });

          return campaigns;
        });
  }

  /// 一次取得店家目前啟用中的優惠活動
  ///
  /// 用於前台預約及後台手動訂單送出前的優惠計算。
  Future<List<DiscountCampaignModel>> getEnabledCampaigns(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const <DiscountCampaignModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _campaignCollection(
          normalizedShopId,
        ).where('enabled', isEqualTo: true).get();

    final List<DiscountCampaignModel> campaigns = snapshot.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return DiscountCampaignModel.fromMap(
            id: document.id,
            data: document.data(),
          );
        })
        .where((DiscountCampaignModel campaign) {
          return !campaign.isUsageLimitReached;
        })
        .toList();

    campaigns.sort((DiscountCampaignModel first, DiscountCampaignModel second) {
      return second.createdAt.compareTo(first.createdAt);
    });

    return campaigns;
  }

  /// 統計會員在指定店家使用各優惠活動的次數
  ///
  /// 回傳格式：
  /// campaignId -> 已使用次數
  Future<Map<String, int>> getMemberCampaignUsage({
    required String shopId,
    required String userId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return const <String, int>{};
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: normalizedShopId)
        .where('userId', isEqualTo: normalizedUserId)
        .get();

    final Map<String, int> usage = <String, int>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String status = (data['status'] ?? '').toString();

      // 已取消的訂單不計入優惠使用次數。
      if (status == 'cancelled') {
        continue;
      }

      final String campaignId = (data['discountCampaignId'] ?? '')
          .toString()
          .trim();

      if (campaignId.isEmpty) {
        continue;
      }

      usage[campaignId] = (usage[campaignId] ?? 0) + 1;
    }

    return usage;
  }

  /// 統計會員在指定店家使用各優惠活動的優惠晚數
  ///
  /// 回傳格式：
  /// campaignId -> 已使用優惠晚數
  Future<Map<String, int>> getMemberCampaignUsedNights({
    required String shopId,
    required String userId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return const <String, int>{};
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: normalizedShopId)
        .where('userId', isEqualTo: normalizedUserId)
        .get();

    final Map<String, int> usedNights = <String, int>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String status = (data['status'] ?? '').toString();

      // 已取消訂單不計入已使用優惠晚數。
      if (status == 'cancelled') {
        continue;
      }

      final String campaignId = (data['discountCampaignId'] ?? '')
          .toString()
          .trim();

      if (campaignId.isEmpty) {
        continue;
      }

      final dynamic rawDiscountUsedNights = data['discountUsedNights'];

      final int discountUsedNights = rawDiscountUsedNights is num
          ? rawDiscountUsedNights.toInt()
          : int.tryParse(rawDiscountUsedNights?.toString() ?? '') ?? 0;

      if (discountUsedNights <= 0) {
        continue;
      }

      usedNights[campaignId] =
          (usedNights[campaignId] ?? 0) + discountUsedNights;
    }

    return usedNights;
  }

  /// 取得單一優惠活動
  Future<DiscountCampaignModel?> getCampaign({
    required String shopId,
    required String campaignId,
  }) async {
    if (shopId.trim().isEmpty || campaignId.trim().isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _campaignCollection(shopId).doc(campaignId).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return DiscountCampaignModel.fromMap(
      id: snapshot.id,
      data: snapshot.data()!,
    );
  }

  /// 建立新的優惠活動
  Future<String> createCampaign({
    required String shopId,
    required String name,
    required String description,
    required DiscountCampaignType type,
    required DiscountValueType valueType,
    required DiscountApplyTarget applyTarget,
    required num discountValue,
    required bool enabled,
    DateTime? startAt,
    DateTime? endAt,
    DiscountDateMatchType? dateMatchType,
    int minimumNights = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int memberUsageLimit = 1,
    int totalUsageLimit = 0,
    bool firstBookingOnly = false,
    bool allowCouponTogether = false,
    List<String> roomTypeIds = const <String>[],
    int newMemberDiscountNights = 0,
    bool limitStayDate = false,
    DateTime? stayStartAt,
    DateTime? stayEndAt,
  }) async {
    _validateCampaign(
      shopId: shopId,
      name: name,
      valueType: valueType,
      discountValue: discountValue,
      startAt: startAt,
      endAt: endAt,
      minimumNights: minimumNights,
      minimumAmount: minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount,
      memberUsageLimit: memberUsageLimit,
      totalUsageLimit: totalUsageLimit,
      newMemberDiscountNights: newMemberDiscountNights,
    );

    final String uid = _auth.currentUser?.uid ?? '';
    final DateTime now = DateTime.now();

    final DocumentReference<Map<String, dynamic>> reference =
        _campaignCollection(shopId).doc();

    final DiscountCampaignModel campaign = DiscountCampaignModel(
      id: reference.id,
      shopId: shopId.trim(),
      name: name.trim(),
      description: description.trim(),
      type: type,
      valueType: valueType,
      applyTarget: applyTarget,
      discountValue: discountValue,
      enabled: enabled,
      startAt: startAt,
      endAt: endAt,
      dateMatchType: dateMatchType,
      minimumNights: minimumNights,
      minimumAmount: minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount,
      memberUsageLimit: memberUsageLimit,
      totalUsageLimit: totalUsageLimit,
      usedCount: 0,
      firstBookingOnly: firstBookingOnly,
      allowCouponTogether: allowCouponTogether,
      roomTypeIds: roomTypeIds,
      newMemberDiscountNights: newMemberDiscountNights,
      limitStayDate: limitStayDate,
      stayStartAt: stayStartAt,
      stayEndAt: stayEndAt,
      createdBy: uid,
      createdAt: now,
      updatedAt: now,
    );

    await reference.set(campaign.toMap());

    return reference.id;
  }

  /// 更新既有優惠活動
  Future<void> updateCampaign({
    required String shopId,
    required String campaignId,
    required String name,
    required String description,
    required DiscountCampaignType type,
    required DiscountValueType valueType,
    required DiscountApplyTarget applyTarget,
    required num discountValue,
    required bool enabled,
    DateTime? startAt,
    DateTime? endAt,
    DiscountDateMatchType? dateMatchType,
    int minimumNights = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int memberUsageLimit = 1,
    int totalUsageLimit = 0,
    bool firstBookingOnly = false,
    bool allowCouponTogether = false,
    List<String> roomTypeIds = const <String>[],
    int newMemberDiscountNights = 0,
    bool limitStayDate = false,
    DateTime? stayStartAt,
    DateTime? stayEndAt,
  }) async {
    if (campaignId.trim().isEmpty) {
      throw ArgumentError('優惠活動 ID 不可為空');
    }

    _validateCampaign(
      shopId: shopId,
      name: name,
      valueType: valueType,
      discountValue: discountValue,
      startAt: startAt,
      endAt: endAt,
      minimumNights: minimumNights,
      minimumAmount: minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount,
      memberUsageLimit: memberUsageLimit,
      totalUsageLimit: totalUsageLimit,
      newMemberDiscountNights: newMemberDiscountNights,
    );

    await _campaignCollection(shopId).doc(campaignId).update(<String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'type': type.name,
      'valueType': valueType.name,
      'applyTarget': applyTarget.name,
      'discountValue': discountValue,
      'enabled': enabled,
      'startAt': startAt == null ? null : Timestamp.fromDate(startAt),
      'endAt': endAt == null ? null : Timestamp.fromDate(endAt),
      'dateMatchType': dateMatchType?.name,
      'minimumNights': minimumNights,
      'minimumAmount': minimumAmount,
      'maximumDiscountAmount': maximumDiscountAmount,
      'memberUsageLimit': memberUsageLimit,
      'totalUsageLimit': totalUsageLimit,
      'firstBookingOnly': firstBookingOnly,
      'allowCouponTogether': allowCouponTogether,
      'roomTypeIds': roomTypeIds,
      'newMemberDiscountNights': newMemberDiscountNights,
      'limitStayDate': limitStayDate,
      'stayStartAt': stayStartAt == null
          ? null
          : Timestamp.fromDate(stayStartAt),
      'stayEndAt': stayEndAt == null ? null : Timestamp.fromDate(stayEndAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 單獨切換優惠活動啟用狀態
  Future<void> setCampaignEnabled({
    required String shopId,
    required String campaignId,
    required bool enabled,
  }) async {
    if (shopId.trim().isEmpty || campaignId.trim().isEmpty) {
      throw ArgumentError('店家 ID 或優惠活動 ID 不可為空');
    }

    await _campaignCollection(shopId).doc(campaignId).update(<String, dynamic>{
      'enabled': enabled,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 刪除優惠活動
  ///
  /// 注意：之後若活動已被訂單使用，會再補上不可直接刪除的保護。
  Future<void> deleteCampaign({
    required String shopId,
    required String campaignId,
  }) async {
    if (shopId.trim().isEmpty || campaignId.trim().isEmpty) {
      throw ArgumentError('店家 ID 或優惠活動 ID 不可為空');
    }

    await _campaignCollection(shopId).doc(campaignId).delete();
  }

  void _validateCampaign({
    required String shopId,
    required String name,
    required DiscountValueType valueType,
    required num discountValue,
    required DateTime? startAt,
    required DateTime? endAt,
    required int minimumNights,
    required int minimumAmount,
    required int maximumDiscountAmount,
    required int memberUsageLimit,
    required int totalUsageLimit,
    int newMemberDiscountNights = 0,
  }) {
    if (shopId.trim().isEmpty) {
      throw ArgumentError('店家 ID 不可為空');
    }

    if (name.trim().isEmpty) {
      throw ArgumentError('優惠活動名稱不可為空');
    }

    if (discountValue <= 0) {
      throw ArgumentError('折扣數值必須大於 0');
    }

    if (valueType == DiscountValueType.percent &&
        (discountValue <= 0 || discountValue >= 100)) {
      throw ArgumentError('百分比折扣必須大於 0 且小於 100');
    }

    if (startAt != null && endAt != null && endAt.isBefore(startAt)) {
      throw ArgumentError('優惠結束日期不可早於開始日期');
    }

    if (minimumNights < 0) {
      throw ArgumentError('最低入住晚數不可小於 0');
    }

    if (minimumAmount < 0) {
      throw ArgumentError('最低消費金額不可小於 0');
    }

    if (maximumDiscountAmount < 0) {
      throw ArgumentError('最高折抵金額不可小於 0');
    }

    if (memberUsageLimit < 0) {
      throw ArgumentError('會員使用次數不可小於 0');
    }

    if (totalUsageLimit < 0) {
      throw ArgumentError('活動總使用次數不可小於 0');
    }
    if (newMemberDiscountNights < 0) {
      throw ArgumentError('新會員優惠晚數不可小於 0');
    }
  }
}
