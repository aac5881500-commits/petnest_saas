// lib/core/services/point_exchange_service.dart
// 🎁 點數兌換 Service
// 功能：使用 Firestore Transaction 完成會員扣點、建立點數流水、
// 建立會員優惠券或實體商品兌換紀錄，並同步更新商品與會員兌換次數。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/member_coupon_model.dart';
import '../models/member_point_log_model.dart';
import '../models/member_point_model.dart';
import '../models/point_redemption_model.dart';
import '../models/point_reward_model.dart';
import 'inventory_stock_service.dart';

class PointExchangeService {
  PointExchangeService._();

  static final PointExchangeService instance = PointExchangeService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 監聽指定會員對指定商品的累積兌換次數。
  Stream<int> streamMemberExchangedCount({
    required String shopId,
    required String rewardId,
    required String userId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty ||
        normalizedRewardId.isEmpty ||
        normalizedUserId.isEmpty) {
      return Stream<int>.value(0);
    }

    return _firestore
        .collection('shops')
        .doc(normalizedShopId)
        .collection('point_rewards')
        .doc(normalizedRewardId)
        .collection('member_exchanges')
        .doc(normalizedUserId)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
          final Map<String, dynamic>? data = snapshot.data();

          if (!snapshot.exists || data == null) {
            return 0;
          }

          return (data['exchangedCount'] as num?)?.toInt() ?? 0;
        });
  }

  /// 會員使用點數兌換優惠券或實體商品。
  ///
  /// 成功後回傳：
  /// - 優惠券商品：member_coupons 文件 ID
  /// - 實體商品：point_redemptions 文件 ID
  Future<String> exchangeReward({
    required String shopId,
    required String rewardId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRewardId = rewardId.trim();
    final String userId = _auth.currentUser?.uid ?? '';

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedRewardId.isEmpty) {
      throw ArgumentError('缺少點數兌換商品 ID');
    }

    if (userId.isEmpty) {
      throw StateError('請先登入會員帳號');
    }

    final DocumentReference<Map<String, dynamic>> pointSettingReference =
        _firestore
            .collection('shops')
            .doc(normalizedShopId)
            .collection('settings')
            .doc('points');

    final DocumentReference<Map<String, dynamic>> rewardReference = _firestore
        .collection('shops')
        .doc(normalizedShopId)
        .collection('point_rewards')
        .doc(normalizedRewardId);

    final DocumentReference<Map<String, dynamic>> memberPointReference =
        _firestore
            .collection('shops')
            .doc(normalizedShopId)
            .collection('member_points')
            .doc(userId);

    final DocumentReference<Map<String, dynamic>> shopMemberReference =
        _firestore
            .collection('shops')
            .doc(normalizedShopId)
            .collection('members')
            .doc(userId);

    final DocumentReference<Map<String, dynamic>> userProfileReference =
        _firestore.collection('user_profiles').doc(userId);

    final DocumentReference<Map<String, dynamic>> couponReference = _firestore
        .collection('shops')
        .doc(normalizedShopId)
        .collection('member_coupons')
        .doc();

    final DocumentReference<Map<String, dynamic>> redemptionReference =
        _firestore
            .collection('shops')
            .doc(normalizedShopId)
            .collection('point_redemptions')
            .doc();

    final DocumentReference<Map<String, dynamic>> pointLogReference = _firestore
        .collection('shops')
        .doc(normalizedShopId)
        .collection('member_point_logs')
        .doc();

    final DocumentReference<Map<String, dynamic>> memberExchangeReference =
        rewardReference.collection('member_exchanges').doc(userId);

    try {
      return await _firestore.runTransaction((Transaction transaction) async {
        // Transaction 規定所有讀取必須在寫入之前完成。
        final DocumentSnapshot<Map<String, dynamic>> pointSettingSnapshot =
            await transaction.get(pointSettingReference);

        final DocumentSnapshot<Map<String, dynamic>> rewardSnapshot =
            await transaction.get(rewardReference);

        final DocumentSnapshot<Map<String, dynamic>> memberPointSnapshot =
            await transaction.get(memberPointReference);

        final DocumentSnapshot<Map<String, dynamic>> shopMemberSnapshot =
            await transaction.get(shopMemberReference);

        final DocumentSnapshot<Map<String, dynamic>> userProfileSnapshot =
            await transaction.get(userProfileReference);

        final DocumentSnapshot<Map<String, dynamic>> memberExchangeSnapshot =
            await transaction.get(memberExchangeReference);

        final Map<String, dynamic>? pointSettingData = pointSettingSnapshot
            .data();

        if (!pointSettingSnapshot.exists || pointSettingData == null) {
          throw StateError('店家尚未設定點數制度');
        }

        if (pointSettingData['enabled'] != true) {
          throw StateError('店家目前未啟用點數制度');
        }

        if (pointSettingData['allowPointsExchange'] != true) {
          throw StateError('店家目前未開放點數兌換');
        }

        final Map<String, dynamic>? rewardData = rewardSnapshot.data();

        if (!rewardSnapshot.exists || rewardData == null) {
          throw StateError('找不到此點數兌換商品');
        }

        final PointRewardModel reward = PointRewardModel.fromMap(
          id: rewardSnapshot.id,
          data: rewardData,
        );

        if (!reward.enabled) {
          throw StateError('此兌換商品目前未開放');
        }

        if (reward.pointsCost <= 0) {
          throw StateError('此兌換商品點數設定錯誤');
        }

        if (reward.hasTotalExchangeLimit &&
            reward.exchangedCount >= reward.totalExchangeLimit) {
          throw StateError('此兌換商品已兌換完畢');
        }

        if (reward.hasStockLimit &&
            reward.exchangedCount >= reward.stockQuantity) {
          throw StateError('此商品目前已無庫存');
        }

        final int memberExchangedCount =
            ((memberExchangeSnapshot.data()?['exchangedCount'] ?? 0) as num)
                .toInt();

        if (reward.hasMemberExchangeLimit &&
            memberExchangedCount >= reward.exchangeLimitPerMember) {
          throw StateError('你已達到此商品的兌換次數上限');
        }

        final Map<String, dynamic>? memberPointData = memberPointSnapshot
            .data();

        final MemberPointModel currentPoint =
            memberPointSnapshot.exists && memberPointData != null
            ? MemberPointModel.fromMap(
                shopId: normalizedShopId,
                userId: userId,
                data: memberPointData,
              )
            : MemberPointModel.empty(shopId: normalizedShopId, userId: userId);

        final int balanceBefore = currentPoint.currentPoints;
        final int balanceAfter = balanceBefore - reward.pointsCost;

        if (balanceAfter < 0) {
          throw StateError(
            '點數不足，目前有 $balanceBefore 點，需要 ${reward.pointsCost} 點',
          );
        }

        final _MemberContactInfo memberContact = _resolveMemberContactInfo(
          shopMemberData: shopMemberSnapshot.data() ?? <String, dynamic>{},
          userProfileData: userProfileSnapshot.data() ?? <String, dynamic>{},
          currentUser: _auth.currentUser,
        );

        final DateTime now = DateTime.now();

        final bool isCouponReward = reward.isCouponReward;
        final bool isPhysicalProduct = reward.isPhysicalProduct;

        if (!isCouponReward && !isPhysicalProduct) {
          throw StateError('此兌換商品類型目前尚未開放');
        }

        final String resultId = isCouponReward
            ? couponReference.id
            : redemptionReference.id;

        final String pickupCode = isPhysicalProduct
            ? _buildPickupCode(redemptionReference.id)
            : '';

        final DateTime? expireAt = reward.validDays > 0
            ? now.add(Duration(days: reward.validDays))
            : null;

        final MemberPointModel nextPoint = currentPoint.copyWith(
          currentPoints: balanceAfter,
          totalUsedPoints: currentPoint.totalUsedPoints + reward.pointsCost,
          lastUsedAt: now,
          updatedAt: now,
        );

        final MemberCouponModel? coupon = isCouponReward
            ? _buildCoupon(
                couponId: couponReference.id,
                shopId: normalizedShopId,
                userId: userId,
                reward: reward,
                now: now,
                expireAt: expireAt,
              )
            : null;

        final PointRedemptionModel? redemption = isPhysicalProduct
            ? _buildRedemption(
                redemptionId: redemptionReference.id,
                shopId: normalizedShopId,
                userId: userId,
                reward: reward,
                balanceBefore: balanceBefore,
                balanceAfter: balanceAfter,
                pickupCode: pickupCode,
                expireAt: expireAt,
                memberContact: memberContact,
                now: now,
              )
            : null;

        final MemberPointLogModel pointLog = _buildPointLog(
          logId: pointLogReference.id,
          shopId: normalizedShopId,
          userId: userId,
          reward: reward,
          balanceBefore: balanceBefore,
          balanceAfter: balanceAfter,
          couponId: coupon?.id ?? '',
          redemptionId: redemption?.id ?? '',
          now: now,
        );

        PreparedStockConsumption? inventoryPlan;

        if (isPhysicalProduct &&
            reward.usesCentralInventory &&
            redemption != null) {
          inventoryPlan = await InventoryStockService.instance
              .preparePointRedemptionDeduct(
                transaction: transaction,
                shopId: normalizedShopId,
                redemptionId: redemption.id,
                inventoryItemId: reward.inventoryItemId,
                quantity: reward.inventoryQuantityPerExchange <= 0
                    ? 1
                    : reward.inventoryQuantityPerExchange,
                itemName: reward.name,
                note: '點數兌換立即扣庫存',
              );
        }

        transaction.set(
          memberPointReference,
          nextPoint.toMap(),
          SetOptions(merge: true),
        );

        transaction.set(pointLogReference, pointLog.toMap());

        if (coupon != null) {
          transaction.set(couponReference, coupon.toMap());
        }

        if (redemption != null) {
          transaction.set(redemptionReference, redemption.toMap());
        }

        transaction.update(rewardReference, <String, dynamic>{
          'exchangedCount': reward.exchangedCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final Map<String, dynamic>? memberExchangeData = memberExchangeSnapshot
            .data();

        final bool memberExchangeHasCreatedAt =
            memberExchangeSnapshot.exists &&
            memberExchangeData != null &&
            memberExchangeData['createdAt'] is Timestamp;

        transaction.set(memberExchangeReference, <String, dynamic>{
          'shopId': normalizedShopId,
          'rewardId': reward.id,
          'userId': userId,
          'exchangedCount': memberExchangedCount + 1,
          'lastCouponId': coupon?.id ?? '',
          'lastRedemptionId': redemption?.id ?? '',
          'lastExchangedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),

          // 相容舊版缺少 createdAt 的會員兌換紀錄。
          if (!memberExchangeHasCreatedAt)
            'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (inventoryPlan != null) {
          InventoryStockService.instance.commitPreparedConsumption(
            transaction: transaction,
            prepared: inventoryPlan,
          );
        }

        return resultId;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('PointExchangeService.exchangeReward 發生錯誤：$error');
        debugPrintStack(stackTrace: stackTrace);
      }

      rethrow;
    }
  }

  /// 安全取得會員姓名與電話。
  ///
  /// 資料優先順序：
  /// 1. 店家會員資料
  /// 2. 全域會員資料
  /// 3. Firebase Auth 資料
  _MemberContactInfo _resolveMemberContactInfo({
    required Map<String, dynamic> shopMemberData,
    required Map<String, dynamic> userProfileData,
    required User? currentUser,
  }) {
    final Map<String, dynamic> globalTags = _safeMap(
      userProfileData['globalTags'],
    );

    final String shopMemberName = (shopMemberData['name'] ?? '')
        .toString()
        .trim();

    final String profileName =
        (globalTags['name'] ?? userProfileData['name'] ?? '').toString().trim();

    final String authDisplayName = currentUser?.displayName?.trim() ?? '';

    final String memberName = shopMemberName.isNotEmpty
        ? shopMemberName
        : profileName.isNotEmpty
        ? profileName
        : authDisplayName;

    final String shopMemberPhone = (shopMemberData['phone'] ?? '')
        .toString()
        .trim();

    final String profilePhone =
        (globalTags['phone'] ?? userProfileData['phone'] ?? '')
            .toString()
            .trim();

    final String authPhone = currentUser?.phoneNumber?.trim() ?? '';

    final String memberPhone = shopMemberPhone.isNotEmpty
        ? shopMemberPhone
        : profilePhone.isNotEmpty
        ? profilePhone
        : authPhone;

    return _MemberContactInfo(name: memberName, phone: memberPhone);
  }

  /// 將動態資料安全轉換為 Map。
  ///
  /// 舊會員資料的 globalTags 可能是 List，因此不可直接強制轉型。
  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  /// 建立點數兌換優惠券。
  MemberCouponModel _buildCoupon({
    required String couponId,
    required String shopId,
    required String userId,
    required PointRewardModel reward,
    required DateTime now,
    required DateTime? expireAt,
  }) {
    return MemberCouponModel(
      id: couponId,
      shopId: shopId,
      userId: userId,
      name: reward.name,
      description: reward.description,
      type: reward.couponType,
      applyTarget: reward.applyTarget,
      source: MemberCouponSource.pointsExchange,
      status: MemberCouponStatus.available,
      discountValue: reward.discountValue,
      minimumAmount: reward.minimumAmount,
      maximumDiscountAmount: reward.maximumDiscountAmount,
      freeStayNights: reward.freeStayNights,
      serviceId: reward.serviceId,
      serviceName: reward.serviceName,
      roomTypeIds: reward.roomTypeIds,
      startAt: now,
      expireAt: expireAt,
      usageLimit: reward.usageLimit,
      usedCount: 0,
      issuedBy: userId,
      issuedReason: '會員使用點數兌換',
      pointsCost: reward.pointsCost,
      pointRewardId: reward.id,
      usedBookingId: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 建立實體商品兌換紀錄。
  PointRedemptionModel _buildRedemption({
    required String redemptionId,
    required String shopId,
    required String userId,
    required PointRewardModel reward,
    required int balanceBefore,
    required int balanceAfter,
    required String pickupCode,
    required DateTime? expireAt,
    required _MemberContactInfo memberContact,
    required DateTime now,
  }) {
    return PointRedemptionModel(
      id: redemptionId,
      shopId: shopId,
      userId: userId,
      rewardId: reward.id,
      rewardName: reward.name,
      rewardDescription: reward.description,
      rewardImageUrl: reward.imageUrl,
      fulfillmentNote: reward.fulfillmentNote,
      pointsCost: reward.pointsCost,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      status: PointRedemptionStatus.pendingPickup,
      pickupCode: pickupCode,
      expireAt: expireAt,
      memberName: memberContact.name,
      memberPhone: memberContact.phone,
      useCentralInventory: reward.usesCentralInventory,
      inventoryItemId: reward.inventoryItemId,
      inventoryItemName: reward.inventoryItemName.isEmpty
          ? reward.name
          : reward.inventoryItemName,
      inventoryUnit: reward.inventoryUnit,
      inventoryQuantity: reward.usesCentralInventory
          ? (reward.inventoryQuantityPerExchange <= 0
                ? 1
                : reward.inventoryQuantityPerExchange)
          : 0,
      inventoryDeducted: reward.usesCentralInventory,
      inventoryReturned: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 建立會員點數扣除流水。
  MemberPointLogModel _buildPointLog({
    required String logId,
    required String shopId,
    required String userId,
    required PointRewardModel reward,
    required int balanceBefore,
    required int balanceAfter,
    required String couponId,
    required String redemptionId,
    required DateTime now,
  }) {
    return MemberPointLogModel(
      id: logId,
      shopId: shopId,
      userId: userId,
      type: MemberPointLogType.rewardExchange,
      points: -reward.pointsCost,
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
      reason: '兌換「${reward.name}」',
      operatorUid: userId,
      sourceId: reward.id,
      rewardId: reward.id,
      couponId: couponId,
      redemptionId: redemptionId,
      note: '',
      createdAt: now,
    );
  }

  /// 產生會員到店領取商品時使用的八碼領取碼。
  String _buildPickupCode(String redemptionId) {
    final String normalizedId = redemptionId
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();

    if (normalizedId.length >= 8) {
      return normalizedId.substring(normalizedId.length - 8);
    }

    return normalizedId.padLeft(8, '0');
  }
}

/// 兌換實體商品時保存的會員聯絡資料。
class _MemberContactInfo {
  const _MemberContactInfo({required this.name, required this.phone});

  final String name;
  final String phone;
}
