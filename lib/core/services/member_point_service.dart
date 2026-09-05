// 檔案名稱：lib/core/services/member_point_service.dart
// 功能說明：讀取、監聽與安全調整會員在指定店家的點數餘額
// 🪙 會員點數 Service
// 並支援手動加扣點與訂單完成自動發點

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/member_point_log_model.dart';
import '../models/member_point_model.dart';

class MemberPointService {
  MemberPointService._();

  static final MemberPointService instance = MemberPointService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 會員點數集合
  CollectionReference<Map<String, dynamic>> _memberPointsReference(
    String shopId,
  ) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('member_points');
  }

  /// 會員點數流水集合
  CollectionReference<Map<String, dynamic>> _memberPointLogsReference(
    String shopId,
  ) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('member_point_logs');
  }

  /// 指定會員的點數資料
  DocumentReference<Map<String, dynamic>> _memberPointReference({
    required String shopId,
    required String userId,
  }) {
    return _memberPointsReference(shopId).doc(userId);
  }

  /// 即時監聽會員點數
  ///
  /// 尚未建立資料時，回傳 0 點空資料，
  /// 但不會自動寫入 Firestore。
  Stream<MemberPointModel> streamMemberPoint({
    required String shopId,
    required String userId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return Stream<MemberPointModel>.value(
        MemberPointModel.empty(
          shopId: normalizedShopId,
          userId: normalizedUserId,
        ),
      );
    }

    return _memberPointReference(
      shopId: normalizedShopId,
      userId: normalizedUserId,
    ).snapshots().map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return MemberPointModel.empty(
          shopId: normalizedShopId,
          userId: normalizedUserId,
        );
      }

      return MemberPointModel.fromMap(
        shopId: normalizedShopId,
        userId: normalizedUserId,
        data: data,
      );
    });
  }

  /// 一次取得會員點數
  ///
  /// 尚未建立時回傳 0 點資料。
  Future<MemberPointModel> getMemberPoint({
    required String shopId,
    required String userId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return MemberPointModel.empty(
        shopId: normalizedShopId,
        userId: normalizedUserId,
      );
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _memberPointReference(
          shopId: normalizedShopId,
          userId: normalizedUserId,
        ).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return MemberPointModel.empty(
        shopId: normalizedShopId,
        userId: normalizedUserId,
      );
    }

    return MemberPointModel.fromMap(
      shopId: normalizedShopId,
      userId: normalizedUserId,
      data: data,
    );
  }

  /// 即時監聽指定會員的點數流水
  ///
  /// 依建立時間由新到舊排序。
  Stream<List<MemberPointLogModel>> streamMemberPointLogs({
    required String shopId,
    required String userId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return Stream<List<MemberPointLogModel>>.value(
        const <MemberPointLogModel>[],
      );
    }

    return _memberPointLogsReference(normalizedShopId)
        .where('userId', isEqualTo: normalizedUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map((document) {
            return MemberPointLogModel.fromMap(
              id: document.id,
              data: document.data(),
            );
          }).toList();
        });
  }

  /// 即時監聽店家全部點數兌換紀錄
  ///
  /// 只讀取 rewardExchange 類型，
  /// 並依兌換時間由新到舊排序。
  Stream<List<MemberPointLogModel>> streamShopRewardExchangeLogs({
    required String shopId,
  }) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<MemberPointLogModel>>.value(
        const <MemberPointLogModel>[],
      );
    }

    return _memberPointLogsReference(normalizedShopId)
        .where('type', isEqualTo: MemberPointLogType.rewardExchange.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> document,
          ) {
            return MemberPointLogModel.fromMap(
              id: document.id,
              data: document.data(),
            );
          }).toList();
        });
  }

  /// 確保會員點數資料已建立
  ///
  /// 尚未建立時建立一筆 0 點資料，
  /// 已存在時不覆蓋原本資料。
  Future<MemberPointModel> ensureMemberPoint({
    required String shopId,
    required String userId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    _validateIds(shopId: normalizedShopId, userId: normalizedUserId);

    final DocumentReference<Map<String, dynamic>> reference =
        _memberPointReference(
          shopId: normalizedShopId,
          userId: normalizedUserId,
        );

    return _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(reference);

      final Map<String, dynamic>? data = snapshot.data();

      if (snapshot.exists && data != null) {
        return MemberPointModel.fromMap(
          shopId: normalizedShopId,
          userId: normalizedUserId,
          data: data,
        );
      }

      final MemberPointModel memberPoint = MemberPointModel.empty(
        shopId: normalizedShopId,
        userId: normalizedUserId,
      );

      transaction.set(reference, memberPoint.toMap());

      return memberPoint;
    });
  }

  /// 後台手動增加會員點數
  ///
  /// 點數餘額與流水會在同一個 Transaction 內完成。
  Future<MemberPointModel> addPoints({
    required String shopId,
    required String userId,
    required int points,
    required String reason,
    String note = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();
    final String normalizedReason = reason.trim();

    _validateIds(shopId: normalizedShopId, userId: normalizedUserId);

    if (points <= 0) {
      throw ArgumentError('增加點數必須大於 0');
    }

    if (normalizedReason.isEmpty) {
      throw ArgumentError('請輸入增加點數原因');
    }

    return _changePoints(
      shopId: normalizedShopId,
      userId: normalizedUserId,
      pointsChange: points,
      changeType: _PointChangeType.earn,
      logType: MemberPointLogType.manualAdded,
      reason: normalizedReason,
      note: note.trim(),
    );
  }

  /// 訂單完成後自動發放點數
  ///
  /// bookingId 會同時寫入 sourceId 與 bookingId，
  /// 方便追蹤點數來源及後續防止重複發放。
  Future<MemberPointModel> addBookingPoints({
    required String shopId,
    required String userId,
    required String bookingId,
    required int points,
    String note = '',
    DateTime? expireAt,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();
    final String normalizedBookingId = bookingId.trim();

    _validateIds(shopId: normalizedShopId, userId: normalizedUserId);

    if (normalizedBookingId.isEmpty) {
      throw ArgumentError('缺少訂單 ID');
    }

    if (points <= 0) {
      throw ArgumentError('訂單發放點數必須大於 0');
    }

    final DocumentReference<Map<String, dynamic>> bookingReference = _firestore
        .collection('bookings')
        .doc(normalizedBookingId);

    final DocumentReference<Map<String, dynamic>> pointReference =
        _memberPointReference(
          shopId: normalizedShopId,
          userId: normalizedUserId,
        );

    // 同一筆訂單固定使用同一個流水文件 ID，
    // 再多一層防止同一訂單產生重複流水。
    final DocumentReference<Map<String, dynamic>> logReference =
        _memberPointLogsReference(
          normalizedShopId,
        ).doc('booking_$normalizedBookingId');

    return _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> bookingSnapshot =
          await transaction.get(bookingReference);

      if (!bookingSnapshot.exists) {
        throw StateError('找不到訂單資料');
      }

      final Map<String, dynamic> bookingData =
          bookingSnapshot.data() ?? <String, dynamic>{};

      final bool rewardPointIssued = bookingData['rewardPointIssued'] == true;

      final DocumentSnapshot<Map<String, dynamic>> pointSnapshot =
          await transaction.get(pointReference);

      final Map<String, dynamic>? currentData = pointSnapshot.data();

      final MemberPointModel currentPoint =
          pointSnapshot.exists && currentData != null
          ? MemberPointModel.fromMap(
              shopId: normalizedShopId,
              userId: normalizedUserId,
              data: currentData,
            )
          : MemberPointModel.empty(
              shopId: normalizedShopId,
              userId: normalizedUserId,
            );

      // 已經發過點數，直接回傳目前點數，不再重複增加。
      if (rewardPointIssued) {
        return currentPoint;
      }

      final int balanceBefore = currentPoint.currentPoints;
      final int balanceAfter = balanceBefore + points;
      final DateTime now = DateTime.now();

      final MemberPointModel nextPoint = currentPoint.copyWith(
        currentPoints: balanceAfter,
        totalEarnedPoints: currentPoint.totalEarnedPoints + points,
        lastEarnedAt: now,
        updatedAt: now,
      );

      final MemberPointLogModel log = MemberPointLogModel(
        id: logReference.id,
        shopId: normalizedShopId,
        userId: normalizedUserId,
        type: MemberPointLogType.bookingEarned,
        points: points,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        reason: '完成住宿獲得點數',
        operatorUid: currentOperatorUid,
        sourceId: normalizedBookingId,
        bookingId: normalizedBookingId,
        expireAt: expireAt,
        note: note.trim(),
        createdAt: now,
      );

      transaction.set(
        pointReference,
        nextPoint.toMap(),
        SetOptions(merge: true),
      );

      transaction.set(logReference, log.toMap());

      transaction.update(bookingReference, <String, dynamic>{
        'rewardPointIssued': true,
        'rewardPointAmount': points,
        'rewardPointIssuedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      return nextPoint;
    });
  }

  /// 後台手動扣除會員點數
  ///
  /// 點數不足時會直接阻止，
  /// 不會讓點數餘額變成負數。
  Future<MemberPointModel> deductPoints({
    required String shopId,
    required String userId,
    required int points,
    required String reason,
    String note = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();
    final String normalizedReason = reason.trim();

    _validateIds(shopId: normalizedShopId, userId: normalizedUserId);

    if (points <= 0) {
      throw ArgumentError('扣除點數必須大於 0');
    }

    if (normalizedReason.isEmpty) {
      throw ArgumentError('請輸入扣除點數原因');
    }

    return _changePoints(
      shopId: normalizedShopId,
      userId: normalizedUserId,
      pointsChange: -points,
      changeType: _PointChangeType.use,
      logType: MemberPointLogType.manualDeducted,
      reason: normalizedReason,
      note: note.trim(),
    );
  }

  /// 安全調整會員點數並建立流水
  ///
  /// 點數餘額與流水會在同一個 Transaction 內寫入，
  /// 避免只更新餘額但沒有建立流水。
  Future<MemberPointModel> _changePoints({
    required String shopId,
    required String userId,
    required int pointsChange,
    required _PointChangeType changeType,
    required MemberPointLogType logType,
    required String reason,
    String sourceId = '',
    String bookingId = '',
    String rewardId = '',
    String couponId = '',
    String note = '',
    DateTime? expireAt,
  }) async {
    final DocumentReference<Map<String, dynamic>> pointReference =
        _memberPointReference(shopId: shopId, userId: userId);

    final DocumentReference<Map<String, dynamic>> logReference =
        _memberPointLogsReference(shopId).doc();

    return _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(pointReference);

      final Map<String, dynamic>? currentData = snapshot.data();

      final MemberPointModel currentPoint =
          snapshot.exists && currentData != null
          ? MemberPointModel.fromMap(
              shopId: shopId,
              userId: userId,
              data: currentData,
            )
          : MemberPointModel.empty(shopId: shopId, userId: userId);

      final int balanceBefore = currentPoint.currentPoints;
      final int balanceAfter = balanceBefore + pointsChange;

      if (balanceAfter < 0) {
        throw StateError('會員點數不足');
      }

      final DateTime now = DateTime.now();

      final MemberPointModel nextPoint = currentPoint.copyWith(
        currentPoints: balanceAfter,
        totalEarnedPoints: changeType == _PointChangeType.earn
            ? currentPoint.totalEarnedPoints + pointsChange
            : currentPoint.totalEarnedPoints,
        totalUsedPoints: changeType == _PointChangeType.use
            ? currentPoint.totalUsedPoints + pointsChange.abs()
            : currentPoint.totalUsedPoints,
        lastEarnedAt: changeType == _PointChangeType.earn ? now : null,
        lastUsedAt: changeType == _PointChangeType.use ? now : null,
        updatedAt: now,
      );

      final MemberPointLogModel log = MemberPointLogModel(
        id: logReference.id,
        shopId: shopId,
        userId: userId,
        type: logType,
        points: pointsChange,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        reason: reason,
        operatorUid: currentOperatorUid,
        sourceId: sourceId,
        bookingId: bookingId,
        rewardId: rewardId,
        couponId: couponId,
        expireAt: expireAt,
        note: note,
        createdAt: now,
      );

      transaction.set(
        pointReference,
        nextPoint.toMap(),
        SetOptions(merge: true),
      );

      transaction.set(logReference, log.toMap());

      return nextPoint;
    });
  }

  /// 取得目前登入者 UID
  String get currentOperatorUid => _auth.currentUser?.uid ?? '';

  /// 驗證店家與會員 ID
  void _validateIds({required String shopId, required String userId}) {
    if (shopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (userId.isEmpty) {
      throw ArgumentError('缺少會員 UID');
    }
  }
}

enum _PointChangeType { earn, use }
