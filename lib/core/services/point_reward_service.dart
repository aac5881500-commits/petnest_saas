// lib/core/services/point_reward_service.dart
// 🎁 點數兌換商品 Service
// 功能：管理店家的點數兌換商品新增、修改、查詢、開關與刪除

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/member_coupon_model.dart';
import '../models/point_reward_model.dart';

class PointRewardService {
  PointRewardService._();

  static final PointRewardService instance = PointRewardService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _rewardCollection(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('point_rewards');
  }

  /// 後台即時監聽全部兌換商品
  Stream<List<PointRewardModel>> streamShopRewards(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<PointRewardModel>>.value(const <PointRewardModel>[]);
    }

    return _rewardCollection(normalizedShopId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<PointRewardModel> rewards = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return PointRewardModel.fromMap(id: document.id, data: document.data());
      }).toList();

      rewards.sort(_sortRewards);

      return rewards;
    });
  }

  /// 前台即時監聽目前開放兌換的商品
  Stream<List<PointRewardModel>> streamEnabledRewards(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<PointRewardModel>>.value(const <PointRewardModel>[]);
    }

    return _rewardCollection(
      normalizedShopId,
    ).where('enabled', isEqualTo: true).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<PointRewardModel> rewards = snapshot.docs.map((
        QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
        return PointRewardModel.fromMap(id: document.id, data: document.data());
      }).toList();

      rewards.sort(_sortRewards);

      return rewards;
    });
  }

  /// 一次取得全部兌換商品
  Future<List<PointRewardModel>> getShopRewards(String shopId) async {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const <PointRewardModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _rewardCollection(normalizedShopId).get();

    final List<PointRewardModel> rewards = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) {
      return PointRewardModel.fromMap(id: document.id, data: document.data());
    }).toList();

    rewards.sort(_sortRewards);

    return rewards;
  }

  /// 取得單一兌換商品
  Future<PointRewardModel?> getReward({
    required String shopId,
    required String rewardId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();

    if (normalizedShopId.isEmpty || normalizedRewardId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _rewardCollection(normalizedShopId).doc(normalizedRewardId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return PointRewardModel.fromMap(id: snapshot.id, data: data);
  }

  /// 新增點數兌換商品
  Future<String> createReward({
    required String shopId,
    required String name,
    required int pointsCost,
    required MemberCouponType couponType,
    required MemberCouponApplyTarget applyTarget,
    String description = '',
    PointRewardFulfillmentType fulfillmentType =
        PointRewardFulfillmentType.coupon,
    String couponTemplateId = '',
    String imageUrl = '',
    int stockQuantity = 0,
    String fulfillmentNote = '',
    bool requiresStaffVerification = false,
    num discountValue = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int freeStayNights = 0,
    String serviceId = '',
    String serviceName = '',
    List<String> roomTypeIds = const <String>[],
    int validDays = 30,
    int usageLimit = 1,
    int exchangeLimitPerMember = 0,
    int totalExchangeLimit = 0,
    bool enabled = true,
    int sortOrder = 0,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedName = name.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('請輸入兌換商品名稱');
    }

    _validateReward(
      fulfillmentType: fulfillmentType,
      couponTemplateId: couponTemplateId,
      pointsCost: pointsCost,
      stockQuantity: stockQuantity,
      couponType: couponType,
      discountValue: discountValue,
      freeStayNights: freeStayNights,
      serviceId: serviceId,
      validDays: validDays,
      usageLimit: usageLimit,
      exchangeLimitPerMember: exchangeLimitPerMember,
      totalExchangeLimit: totalExchangeLimit,
    );

    final DateTime now = DateTime.now();

    final DocumentReference<Map<String, dynamic>> rewardReference =
        _rewardCollection(normalizedShopId).doc();

    final PointRewardModel reward = PointRewardModel(
      id: rewardReference.id,
      shopId: normalizedShopId,
      name: normalizedName,
      description: description.trim(),
      pointsCost: pointsCost,
      fulfillmentType: fulfillmentType,
      couponTemplateId: couponTemplateId.trim(),
      imageUrl: imageUrl.trim(),
      stockQuantity: stockQuantity,
      fulfillmentNote: fulfillmentNote.trim(),
      requiresStaffVerification:
          fulfillmentType == PointRewardFulfillmentType.physicalProduct
          ? requiresStaffVerification
          : false,
      couponType: couponType,
      applyTarget: applyTarget,
      discountValue: discountValue,
      minimumAmount: minimumAmount < 0 ? 0 : minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount < 0
          ? 0
          : maximumDiscountAmount,
      freeStayNights: freeStayNights < 0 ? 0 : freeStayNights,
      serviceId: serviceId.trim(),
      serviceName: serviceName.trim(),
      roomTypeIds: _normalizeStringList(roomTypeIds),
      validDays: validDays,
      usageLimit: usageLimit,
      exchangeLimitPerMember: exchangeLimitPerMember,
      totalExchangeLimit: totalExchangeLimit,
      exchangedCount: 0,
      enabled: enabled,
      sortOrder: sortOrder,
      createdBy: _auth.currentUser?.uid ?? '',
      createdAt: now,
      updatedAt: now,
    );

    await rewardReference.set(reward.toMap());

    return rewardReference.id;
  }

  /// 修改點數兌換商品
  Future<void> updateReward({
    required String shopId,
    required String rewardId,
    required String name,
    required int pointsCost,
    required MemberCouponType couponType,
    required MemberCouponApplyTarget applyTarget,
    String description = '',
    PointRewardFulfillmentType fulfillmentType =
        PointRewardFulfillmentType.coupon,
    String couponTemplateId = '',
    String imageUrl = '',
    int stockQuantity = 0,
    String fulfillmentNote = '',
    bool requiresStaffVerification = false,
    num discountValue = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int freeStayNights = 0,
    String serviceId = '',
    String serviceName = '',
    List<String> roomTypeIds = const <String>[],
    int validDays = 30,
    int usageLimit = 1,
    int exchangeLimitPerMember = 0,
    int totalExchangeLimit = 0,
    bool enabled = true,
    int sortOrder = 0,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();
    final String normalizedName = name.trim();

    if (normalizedShopId.isEmpty || normalizedRewardId.isEmpty) {
      throw ArgumentError('兌換商品資料不完整');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('請輸入兌換商品名稱');
    }

    _validateReward(
      fulfillmentType: fulfillmentType,
      couponTemplateId: couponTemplateId,
      pointsCost: pointsCost,
      stockQuantity: stockQuantity,
      couponType: couponType,
      discountValue: discountValue,
      freeStayNights: freeStayNights,
      serviceId: serviceId,
      validDays: validDays,
      usageLimit: usageLimit,
      exchangeLimitPerMember: exchangeLimitPerMember,
      totalExchangeLimit: totalExchangeLimit,
    );

    final DocumentReference<Map<String, dynamic>> rewardReference =
        _rewardCollection(normalizedShopId).doc(normalizedRewardId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(rewardReference);

      final Map<String, dynamic>? currentData = snapshot.data();

      if (!snapshot.exists || currentData == null) {
        throw StateError('找不到此兌換商品');
      }

      final PointRewardModel currentReward = PointRewardModel.fromMap(
        id: snapshot.id,
        data: currentData,
      );

      if (totalExchangeLimit > 0 &&
          totalExchangeLimit < currentReward.exchangedCount) {
        throw StateError(
          '總兌換上限不能低於目前已兌換數量 '
          '${currentReward.exchangedCount}',
        );
      }
      if (stockQuantity > 0 && stockQuantity < currentReward.exchangedCount) {
        throw StateError(
          '商品庫存不能低於目前已兌換數量 '
          '${currentReward.exchangedCount}',
        );
      }

      transaction.update(rewardReference, <String, dynamic>{
        'name': normalizedName,
        'description': description.trim(),
        'pointsCost': pointsCost,
        'fulfillmentType': fulfillmentType.name,
        'couponTemplateId': couponTemplateId.trim(),
        'imageUrl': imageUrl.trim(),
        'stockQuantity': stockQuantity,
        'fulfillmentNote': fulfillmentNote.trim(),
        'requiresStaffVerification':
            fulfillmentType == PointRewardFulfillmentType.physicalProduct
            ? requiresStaffVerification
            : false,
        'couponType': couponType.name,
        'applyTarget': applyTarget.name,
        'discountValue': discountValue,
        'minimumAmount': minimumAmount < 0 ? 0 : minimumAmount,
        'maximumDiscountAmount': maximumDiscountAmount < 0
            ? 0
            : maximumDiscountAmount,
        'freeStayNights': freeStayNights < 0 ? 0 : freeStayNights,
        'serviceId': serviceId.trim(),
        'serviceName': serviceName.trim(),
        'roomTypeIds': _normalizeStringList(roomTypeIds),
        'validDays': validDays,
        'usageLimit': usageLimit,
        'exchangeLimitPerMember': exchangeLimitPerMember,
        'totalExchangeLimit': totalExchangeLimit,
        'enabled': enabled,
        'sortOrder': sortOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 開啟或關閉兌換商品
  Future<void> setRewardEnabled({
    required String shopId,
    required String rewardId,
    required bool enabled,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();

    if (normalizedShopId.isEmpty || normalizedRewardId.isEmpty) {
      throw ArgumentError('兌換商品資料不完整');
    }

    await _rewardCollection(normalizedShopId).doc(normalizedRewardId).update(
      <String, dynamic>{
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// 修改前台顯示順序
  Future<void> updateSortOrder({
    required String shopId,
    required String rewardId,
    required int sortOrder,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();

    if (normalizedShopId.isEmpty || normalizedRewardId.isEmpty) {
      throw ArgumentError('兌換商品資料不完整');
    }

    await _rewardCollection(normalizedShopId).doc(normalizedRewardId).update(
      <String, dynamic>{
        'sortOrder': sortOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// 刪除尚未有人兌換的商品
  ///
  /// 已有兌換紀錄時不可刪除，只能關閉，
  /// 避免日後找不到會員優惠券的來源設定。
  Future<void> deleteReward({
    required String shopId,
    required String rewardId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();

    if (normalizedShopId.isEmpty || normalizedRewardId.isEmpty) {
      throw ArgumentError('兌換商品資料不完整');
    }

    final DocumentReference<Map<String, dynamic>> rewardReference =
        _rewardCollection(normalizedShopId).doc(normalizedRewardId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(rewardReference);

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return;
      }

      final PointRewardModel reward = PointRewardModel.fromMap(
        id: snapshot.id,
        data: data,
      );

      if (reward.exchangedCount > 0) {
        throw StateError('此商品已有兌換紀錄，請改為關閉，不可刪除');
      }

      transaction.delete(rewardReference);
    });
  }

  int _sortRewards(PointRewardModel first, PointRewardModel second) {
    final int sortOrderCompare = first.sortOrder.compareTo(second.sortOrder);

    if (sortOrderCompare != 0) {
      return sortOrderCompare;
    }

    return second.createdAt.compareTo(first.createdAt);
  }

  List<String> _normalizeStringList(List<String> values) {
    return values
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  void _validateReward({
    required PointRewardFulfillmentType fulfillmentType,
    required String couponTemplateId,
    required int pointsCost,
    required int stockQuantity,
    required MemberCouponType couponType,
    required num discountValue,
    required int freeStayNights,
    required String serviceId,
    required int validDays,
    required int usageLimit,
    required int exchangeLimitPerMember,
    required int totalExchangeLimit,
  }) {
    if (pointsCost <= 0) {
      throw ArgumentError('兌換點數必須大於 0');
    }

    if (stockQuantity < 0) {
      throw ArgumentError('商品庫存不能小於 0');
    }

    if (validDays < 0) {
      throw ArgumentError('有效天數不能小於 0');
    }

    if (exchangeLimitPerMember < 0) {
      throw ArgumentError('會員兌換上限不能小於 0');
    }

    if (totalExchangeLimit < 0) {
      throw ArgumentError('總兌換上限不能小於 0');
    }

    // 實體商品與現場服務不需要驗證優惠券折扣內容。
    if (fulfillmentType != PointRewardFulfillmentType.coupon) {
      return;
    }

    if (usageLimit <= 0) {
      throw ArgumentError('優惠券使用次數必須大於 0');
    }

    // 已連結優惠券模板時，優惠內容會從模板取得。
    if (couponTemplateId.trim().isNotEmpty) {
      return;
    }

    // 相容尚未改成優惠券模板的舊資料。
    switch (couponType) {
      case MemberCouponType.fixedAmount:
        if (discountValue <= 0) {
          throw ArgumentError('固定金額折價券的折抵金額必須大於 0');
        }
        break;

      case MemberCouponType.percent:
        if (discountValue <= 0 || discountValue >= 100) {
          throw ArgumentError('百分比折扣必須設定 1 至 99');
        }
        break;

      case MemberCouponType.freeStay:
        if (freeStayNights <= 0) {
          throw ArgumentError('住宿券的免費住宿晚數必須大於 0');
        }
        break;

      case MemberCouponType.freeService:
        if (serviceId.trim().isEmpty) {
          throw ArgumentError('服務券必須指定服務項目');
        }
        break;
    }
  }
}
