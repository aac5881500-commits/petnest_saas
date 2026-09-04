// lib/core/services/point_redemption_service.dart
// 🎁 點數實體商品兌換 Service
// 功能：提供會員實體商品紀錄、後台待領取清單、
// 領取碼查詢、店員完成商品交付、取消兌換、退回點數與標記過期。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/member_point_log_model.dart';
import '../models/member_point_model.dart';
import '../models/point_redemption_model.dart';

class PointRedemptionService {
  PointRedemptionService._();

  static final PointRedemptionService instance = PointRedemptionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _redemptionsReference(
    String shopId,
  ) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('point_redemptions');
  }

  /// 監聽目前登入會員在指定店家的實體商品兌換紀錄
  Stream<List<PointRedemptionModel>> streamMyRedemptions({
    required String shopId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String userId = _auth.currentUser?.uid ?? '';

    if (normalizedShopId.isEmpty || userId.isEmpty) {
      return Stream<List<PointRedemptionModel>>.value(
        const <PointRedemptionModel>[],
      );
    }

    return _redemptionsReference(normalizedShopId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  /// 監聽店家指定會員的實體商品兌換紀錄。
  ///
  /// 供會員詳情頁使用，依建立時間由新到舊排列。
  Stream<List<PointRedemptionModel>> streamMemberRedemptions({
    required String shopId,
    required String userId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return Stream<List<PointRedemptionModel>>.value(
        const <PointRedemptionModel>[],
      );
    }

    return _redemptionsReference(normalizedShopId)
        .where('userId', isEqualTo: normalizedUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshot);
  }

  /// 監聽店家全部實體商品兌換紀錄
  ///
  /// 供店主及有權限的員工後台使用。
  Stream<List<PointRedemptionModel>> streamShopRedemptions({
    required String shopId,
  }) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<PointRedemptionModel>>.value(
        const <PointRedemptionModel>[],
      );
    }

    return _redemptionsReference(
      normalizedShopId,
    ).orderBy('createdAt', descending: true).snapshots().map(_mapSnapshot);
  }

  /// 監聽店家目前待領取的實體商品
  Stream<List<PointRedemptionModel>> streamPendingPickups({
    required String shopId,
  }) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<PointRedemptionModel>>.value(
        const <PointRedemptionModel>[],
      );
    }

    return _redemptionsReference(normalizedShopId)
        .where('status', isEqualTo: PointRedemptionStatus.pendingPickup.name)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(_mapSnapshot);
  }

  /// 取得單筆實體商品兌換紀錄
  Future<PointRedemptionModel?> getRedemption({
    required String shopId,
    required String redemptionId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRedemptionId = redemptionId.trim();

    if (normalizedShopId.isEmpty || normalizedRedemptionId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _redemptionsReference(
          normalizedShopId,
        ).doc(normalizedRedemptionId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return PointRedemptionModel.fromMap(id: snapshot.id, data: data);
  }

  /// 使用領取碼查詢待領取商品
  ///
  /// 領取碼不分英文大小寫。
  Future<PointRedemptionModel?> findPendingByPickupCode({
    required String shopId,
    required String pickupCode,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedPickupCode = pickupCode.trim().toUpperCase();

    if (normalizedShopId.isEmpty || normalizedPickupCode.isEmpty) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _redemptionsReference(normalizedShopId)
            .where('pickupCode', isEqualTo: normalizedPickupCode)
            .where(
              'status',
              isEqualTo: PointRedemptionStatus.pendingPickup.name,
            )
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final QueryDocumentSnapshot<Map<String, dynamic>> document =
        snapshot.docs.first;

    return PointRedemptionModel.fromMap(id: document.id, data: document.data());
  }

  /// 店員確認已交付商品
  Future<void> markAsPickedUp({
    required String shopId,
    required String redemptionId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRedemptionId = redemptionId.trim();
    final String operatorUid = _auth.currentUser?.uid ?? '';

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedRedemptionId.isEmpty) {
      throw ArgumentError('缺少實體商品兌換紀錄 ID');
    }

    if (operatorUid.isEmpty) {
      throw StateError('請先登入店員帳號');
    }

    final DocumentReference<Map<String, dynamic>> redemptionReference =
        _redemptionsReference(normalizedShopId).doc(normalizedRedemptionId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> redemptionSnapshot =
          await transaction.get(redemptionReference);

      final Map<String, dynamic>? redemptionData = redemptionSnapshot.data();

      if (!redemptionSnapshot.exists || redemptionData == null) {
        throw StateError('找不到此實體商品兌換紀錄');
      }

      final PointRedemptionModel redemption = PointRedemptionModel.fromMap(
        id: redemptionSnapshot.id,
        data: redemptionData,
      );

      if (redemption.status == PointRedemptionStatus.pickedUp) {
        throw StateError('此商品已經完成領取');
      }

      if (redemption.status == PointRedemptionStatus.cancelled) {
        throw StateError('此兌換紀錄已取消，無法核銷');
      }

      if (redemption.status == PointRedemptionStatus.expired) {
        throw StateError('此兌換紀錄已過期，無法核銷');
      }

      if (redemption.hasExpired) {
        throw StateError('此商品已超過領取期限');
      }

      if (redemption.status != PointRedemptionStatus.pendingPickup) {
        throw StateError('此商品目前不是待領取狀態');
      }

      transaction.update(redemptionReference, <String, dynamic>{
        'status': PointRedemptionStatus.pickedUp.name,
        'pickedUpAt': FieldValue.serverTimestamp(),
        'pickedUpBy': operatorUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 店家取消實體商品兌換
  ///
  /// [refundPoints] 為 true 時，會將本次兌換使用的點數退回會員。
  ///
  /// 取消紀錄、商品兌換數量、會員兌換次數、會員點數與點數流水，
  /// 會在同一個 Firestore Transaction 中完成。
  Future<void> cancelRedemption({
    required String shopId,
    required String redemptionId,
    required String reason,
    required bool refundPoints,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRedemptionId = redemptionId.trim();
    final String normalizedReason = reason.trim();
    final String operatorUid = _auth.currentUser?.uid ?? '';

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedRedemptionId.isEmpty) {
      throw ArgumentError('缺少實體商品兌換紀錄 ID');
    }

    if (normalizedReason.isEmpty) {
      throw ArgumentError('請填寫取消原因');
    }

    if (operatorUid.isEmpty) {
      throw StateError('請先登入店員帳號');
    }

    final PointRedemptionModel? existing = await getRedemption(
      shopId: normalizedShopId,
      redemptionId: normalizedRedemptionId,
    );
    if (existing != null &&
        existing.useCentralInventory &&
        existing.inventoryItemId.trim().isNotEmpty) {
      try {
        await FirebaseFunctions.instanceFor(
          region: 'asia-east1',
        ).httpsCallable('cancelPointRedemption').call(<String, dynamic>{
          'shopId': normalizedShopId,
          'redemptionId': normalizedRedemptionId,
          'reason': normalizedReason,
          'refundPoints': refundPoints,
        });
      } on FirebaseFunctionsException catch (error) {
        throw StateError(error.message ?? '無法取消兌換');
      }
      return;
    }

    final DocumentReference<Map<String, dynamic>> redemptionReference =
        _redemptionsReference(normalizedShopId).doc(normalizedRedemptionId);

    await _firestore.runTransaction((Transaction transaction) async {
      /*
       * Firestore Transaction 規則：
       * 所有 transaction.get() 必須先執行完，
       * 才可以開始 transaction.update() 或 transaction.set()。
       */

      final DocumentSnapshot<Map<String, dynamic>> redemptionSnapshot =
          await transaction.get(redemptionReference);

      final Map<String, dynamic>? redemptionData = redemptionSnapshot.data();

      if (!redemptionSnapshot.exists || redemptionData == null) {
        throw StateError('找不到此實體商品兌換紀錄');
      }

      final PointRedemptionModel redemption = PointRedemptionModel.fromMap(
        id: redemptionSnapshot.id,
        data: redemptionData,
      );

      if (redemption.status == PointRedemptionStatus.pickedUp) {
        throw StateError('商品已完成領取，無法取消');
      }

      if (redemption.status == PointRedemptionStatus.cancelled) {
        throw StateError('此兌換紀錄已經取消');
      }

      if (redemption.status == PointRedemptionStatus.expired) {
        throw StateError('此兌換紀錄已過期，無法直接取消');
      }

      if (redemption.status != PointRedemptionStatus.pendingPickup) {
        throw StateError('只有待領取商品可以取消');
      }

      if (redemption.useCentralInventory &&
          redemption.inventoryItemId.trim().isNotEmpty) {
        throw StateError('此兌換需由後端取消，請再試一次');
      }

      if (refundPoints && redemption.pointsRefunded) {
        throw StateError('此兌換紀錄已經退回點數');
      }

      if (redemption.userId.trim().isEmpty) {
        throw StateError('兌換紀錄缺少會員 UID');
      }

      if (redemption.rewardId.trim().isEmpty) {
        throw StateError('兌換紀錄缺少商品 ID');
      }

      final DocumentReference<Map<String, dynamic>> rewardReference = _firestore
          .collection('shops')
          .doc(normalizedShopId)
          .collection('point_rewards')
          .doc(redemption.rewardId);

      final DocumentReference<Map<String, dynamic>> memberExchangeReference =
          rewardReference.collection('member_exchanges').doc(redemption.userId);

      final DocumentReference<Map<String, dynamic>> memberPointReference =
          _firestore
              .collection('shops')
              .doc(normalizedShopId)
              .collection('member_points')
              .doc(redemption.userId);

      final DocumentReference<Map<String, dynamic>> pointLogReference =
          _firestore
              .collection('shops')
              .doc(normalizedShopId)
              .collection('member_point_logs')
              .doc();

      /*
       * 先完成所有可能需要的讀取。
       */
      final DocumentSnapshot<Map<String, dynamic>> rewardSnapshot =
          await transaction.get(rewardReference);

      final DocumentSnapshot<Map<String, dynamic>> memberExchangeSnapshot =
          await transaction.get(memberExchangeReference);

      DocumentSnapshot<Map<String, dynamic>>? memberPointSnapshot;

      if (refundPoints) {
        memberPointSnapshot = await transaction.get(memberPointReference);
      }

      final Map<String, dynamic>? rewardData = rewardSnapshot.data();

      final Map<String, dynamic>? memberExchangeData = memberExchangeSnapshot
          .data();

      final int exchangedCount =
          (rewardData?['exchangedCount'] as num?)?.toInt() ?? 0;

      final int memberExchangedCount =
          (memberExchangeData?['exchangedCount'] as num?)?.toInt() ?? 0;

      MemberPointModel? nextMemberPoint;
      MemberPointLogModel? refundLog;

      if (refundPoints) {
        final Map<String, dynamic>? memberPointData = memberPointSnapshot
            ?.data();

        final MemberPointModel currentMemberPoint =
            memberPointSnapshot?.exists == true && memberPointData != null
            ? MemberPointModel.fromMap(
                shopId: normalizedShopId,
                userId: redemption.userId,
                data: memberPointData,
              )
            : MemberPointModel.empty(
                shopId: normalizedShopId,
                userId: redemption.userId,
              );

        final int balanceBefore = currentMemberPoint.currentPoints;

        final int balanceAfter = balanceBefore + redemption.pointsCost;

        final int calculatedTotalUsedPoints =
            currentMemberPoint.totalUsedPoints - redemption.pointsCost;

        final int nextTotalUsedPoints = calculatedTotalUsedPoints < 0
            ? 0
            : calculatedTotalUsedPoints;

        final DateTime now = DateTime.now();

        nextMemberPoint = currentMemberPoint.copyWith(
          currentPoints: balanceAfter,
          totalUsedPoints: nextTotalUsedPoints,
          updatedAt: now,
        );

        refundLog = MemberPointLogModel(
          id: pointLogReference.id,
          shopId: normalizedShopId,
          userId: redemption.userId,
          type: MemberPointLogType.refunded,

          // 退回點數屬於增加點數，所以使用正數。
          points: redemption.pointsCost,

          balanceBefore: balanceBefore,
          balanceAfter: balanceAfter,
          reason: '取消兌換「${redemption.rewardName}」退回點數',
          operatorUid: operatorUid,
          sourceId: redemption.id,
          rewardId: redemption.rewardId,
          redemptionId: redemption.id,
          note: normalizedReason,
          createdAt: now,
        );
      }

      /*
       * 所有讀取完成後，才開始寫入。
       */

      transaction.update(redemptionReference, <String, dynamic>{
        'status': PointRedemptionStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': operatorUid,
        'cancelReason': normalizedReason,
        'pointsRefunded': refundPoints,
        'pointsRefundedAt': refundPoints ? FieldValue.serverTimestamp() : null,
        'pointsRefundedBy': refundPoints ? operatorUid : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (rewardSnapshot.exists && rewardData != null) {
        transaction.update(rewardReference, <String, dynamic>{
          'exchangedCount': exchangedCount > 0 ? exchangedCount - 1 : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (memberExchangeSnapshot.exists) {
        transaction.set(memberExchangeReference, <String, dynamic>{
          'exchangedCount': memberExchangedCount > 0
              ? memberExchangedCount - 1
              : 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (nextMemberPoint != null && refundLog != null) {
        transaction.set(
          memberPointReference,
          nextMemberPoint.toMap(),
          SetOptions(merge: true),
        );

        transaction.set(pointLogReference, refundLog.toMap());
      }
    });
  }

  /// 將已超過期限的待領取商品標記為過期
  ///
  /// 這個方法目前只更新狀態，不會自動退還點數。
  Future<void> markAsExpired({
    required String shopId,
    required String redemptionId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedRedemptionId = redemptionId.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedRedemptionId.isEmpty) {
      throw ArgumentError('缺少實體商品兌換紀錄 ID');
    }

    final DocumentReference<Map<String, dynamic>> redemptionReference =
        _redemptionsReference(normalizedShopId).doc(normalizedRedemptionId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> redemptionSnapshot =
          await transaction.get(redemptionReference);

      final Map<String, dynamic>? redemptionData = redemptionSnapshot.data();

      if (!redemptionSnapshot.exists || redemptionData == null) {
        throw StateError('找不到此實體商品兌換紀錄');
      }

      final PointRedemptionModel redemption = PointRedemptionModel.fromMap(
        id: redemptionSnapshot.id,
        data: redemptionData,
      );

      if (redemption.status != PointRedemptionStatus.pendingPickup) {
        throw StateError('只有待領取商品可以標記過期');
      }

      if (!redemption.hasExpired) {
        throw StateError('此商品尚未超過領取期限');
      }

      transaction.update(redemptionReference, <String, dynamic>{
        'status': PointRedemptionStatus.expired.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  List<PointRedemptionModel> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) {
      return PointRedemptionModel.fromMap(
        id: document.id,
        data: document.data(),
      );
    }).toList();
  }
}
