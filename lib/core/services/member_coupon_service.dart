// 檔案名稱：lib/core/services/member_coupon_service.dart
// 功能說明：管理會員優惠券的發放、查詢、核銷、退回與撤銷
// 🎟️ 會員優惠券 Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/coupon_template_model.dart';
import '../models/member_coupon_model.dart';

class MemberCouponService {
  MemberCouponService._();

  static final MemberCouponService instance = MemberCouponService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _couponCollection(String shopId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('member_coupons');
  }

  /// 即時監聽店家的全部會員優惠券
  ///
  /// 後台未來可用於優惠券管理與查詢。
  Stream<List<MemberCouponModel>> streamShopCoupons(String shopId) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return Stream<List<MemberCouponModel>>.value(const <MemberCouponModel>[]);
    }

    return _couponCollection(normalizedShopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_couponListFromSnapshot);
  }

  /// 即時監聽指定會員在此店家的全部優惠券
  Stream<List<MemberCouponModel>> streamMemberCoupons({
    required String shopId,
    required String userId,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return Stream<List<MemberCouponModel>>.value(const <MemberCouponModel>[]);
    }

    return _couponCollection(
      normalizedShopId,
    ).where('userId', isEqualTo: normalizedUserId).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final List<MemberCouponModel> coupons = _couponListFromSnapshot(snapshot);

      coupons.sort((MemberCouponModel first, MemberCouponModel second) {
        return second.createdAt.compareTo(first.createdAt);
      });

      return coupons;
    });
  }

  /// 一次取得指定會員在此店家的全部優惠券
  Future<List<MemberCouponModel>> getMemberCoupons({
    required String shopId,
    required String userId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return const <MemberCouponModel>[];
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _couponCollection(
          normalizedShopId,
        ).where('userId', isEqualTo: normalizedUserId).get();

    final List<MemberCouponModel> coupons = _couponListFromSnapshot(snapshot);

    coupons.sort((MemberCouponModel first, MemberCouponModel second) {
      return second.createdAt.compareTo(first.createdAt);
    });

    return coupons;
  }

  /// 一次取得會員目前可嘗試使用的優惠券
  ///
  /// 此處只檢查：
  /// 1. 優惠券狀態
  /// 2. 開始使用時間
  /// 3. 使用期限
  /// 4. 使用次數
  ///
  /// 真正套入訂單時，仍需檢查最低消費、房型與搭配活動限制。
  Future<List<MemberCouponModel>> getAvailableMemberCoupons({
    required String shopId,
    required String userId,
  }) async {
    final List<MemberCouponModel> coupons = await getMemberCoupons(
      shopId: shopId,
      userId: userId,
    );

    return coupons
        .where((MemberCouponModel coupon) => coupon.canUseNow)
        .toList();
  }

  /// 取得單一會員優惠券
  Future<MemberCouponModel?> getCoupon({
    required String shopId,
    required String couponId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedCouponId = couponId.trim();

    if (normalizedShopId.isEmpty || normalizedCouponId.isEmpty) {
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _couponCollection(normalizedShopId).doc(normalizedCouponId).get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return MemberCouponModel.fromMap(id: snapshot.id, data: data);
  }

  /// 依照優惠券模板手動發放給指定會員
  Future<String> issueManualCouponFromTemplate({
    required CouponTemplateModel template,
    required String userId,
    String issuedReason = '',
  }) async {
    final String normalizedUserId = userId.trim();

    if (template.shopId.trim().isEmpty) {
      throw ArgumentError('優惠券模板缺少店家 ID');
    }

    if (template.id.trim().isEmpty) {
      throw ArgumentError('缺少優惠券模板 ID');
    }

    if (normalizedUserId.isEmpty) {
      throw ArgumentError('缺少會員 UID');
    }

    if (!template.enabled) {
      throw StateError('此優惠券模板目前已停用');
    }

    final DateTime now = DateTime.now();

    final DateTime? expireAt = template.validDays > 0
        ? DateTime(
            now.year,
            now.month,
            now.day + template.validDays,
            23,
            59,
            59,
            999,
          )
        : null;

    return issueManualCoupon(
      shopId: template.shopId,
      userId: normalizedUserId,
      name: template.name,
      type: template.type,
      applyTarget: template.applyTarget,
      description: template.description,
      discountValue: template.discountValue,
      minimumAmount: template.minimumAmount,
      maximumDiscountAmount: template.maximumDiscountAmount,
      freeStayNights: template.freeStayNights,
      serviceId: template.serviceId,
      serviceName: template.serviceName,
      serviceCategory: template.serviceCategory,
      roomTypeIds: template.roomTypeIds,
      startAt: now,
      expireAt: expireAt,
      usageLimit: template.usageLimit,
      issuedReason: issuedReason,
    );
  }

  /// 店家後台手動發放優惠券
  Future<String> issueManualCoupon({
    required String shopId,
    required String userId,
    required String name,
    required MemberCouponType type,
    required MemberCouponApplyTarget applyTarget,
    String description = '',
    num discountValue = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int freeStayNights = 0,
    String serviceId = '',
    String serviceName = '',
    CouponServiceCategory serviceCategory = CouponServiceCategory.value,
    List<String> roomTypeIds = const <String>[],
    DateTime? startAt,
    DateTime? expireAt,
    int usageLimit = 1,
    String issuedReason = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();
    final String normalizedName = name.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedUserId.isEmpty) {
      throw ArgumentError('缺少會員 UID');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('請輸入優惠券名稱');
    }

    _validateCouponContent(
      type: type,
      discountValue: discountValue,
      freeStayNights: freeStayNights,
      serviceId: serviceId,
      usageLimit: usageLimit,
      startAt: startAt,
      expireAt: expireAt,
    );

    final DateTime now = DateTime.now();
    final DocumentReference<Map<String, dynamic>> couponReference =
        _couponCollection(normalizedShopId).doc();

    final MemberCouponModel coupon = MemberCouponModel(
      id: couponReference.id,
      shopId: normalizedShopId,
      userId: normalizedUserId,
      name: normalizedName,
      description: description.trim(),
      type: type,
      applyTarget: applyTarget,
      source: MemberCouponSource.manual,
      status: MemberCouponStatus.available,
      discountValue: discountValue,
      minimumAmount: minimumAmount < 0 ? 0 : minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount < 0
          ? 0
          : maximumDiscountAmount,
      freeStayNights: freeStayNights < 0 ? 0 : freeStayNights,
      serviceId: serviceId.trim(),
      serviceName: serviceName.trim(),
      serviceCategory: serviceCategory,
      roomTypeIds: roomTypeIds
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toSet()
          .toList(),
      startAt: startAt,
      expireAt: expireAt,
      usageLimit: usageLimit,
      usedCount: 0,
      issuedBy: _auth.currentUser?.uid ?? '',
      issuedReason: issuedReason.trim(),
      pointsCost: 0,
      pointRewardId: '',
      usedBookingId: '',
      createdAt: now,
      updatedAt: now,
    );

    await couponReference.set(coupon.toMap());

    return couponReference.id;
  }

  /// 點數兌換成功後建立優惠券
  ///
  /// 點數扣除會在未來的點數 Service 交易中處理。
  /// 此方法目前只負責產生會員持有券。
  Future<String> issuePointsExchangeCoupon({
    required String shopId,
    required String userId,
    required String pointRewardId,
    required int pointsCost,
    required String name,
    required MemberCouponType type,
    required MemberCouponApplyTarget applyTarget,
    String description = '',
    num discountValue = 0,
    int minimumAmount = 0,
    int maximumDiscountAmount = 0,
    int freeStayNights = 0,
    String serviceId = '',
    String serviceName = '',
    CouponServiceCategory serviceCategory = CouponServiceCategory.value,
    List<String> roomTypeIds = const <String>[],
    DateTime? startAt,
    DateTime? expireAt,
    int usageLimit = 1,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();
    final String normalizedRewardId = pointRewardId.trim();
    final String normalizedName = name.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedUserId.isEmpty) {
      throw ArgumentError('缺少會員 UID');
    }

    if (normalizedRewardId.isEmpty) {
      throw ArgumentError('缺少點數兌換商品 ID');
    }

    if (normalizedName.isEmpty) {
      throw ArgumentError('缺少兌換商品名稱');
    }

    if (pointsCost <= 0) {
      throw ArgumentError('兌換點數必須大於 0');
    }

    _validateCouponContent(
      type: type,
      discountValue: discountValue,
      freeStayNights: freeStayNights,
      serviceId: serviceId,
      usageLimit: usageLimit,
      startAt: startAt,
      expireAt: expireAt,
    );

    final DateTime now = DateTime.now();
    final DocumentReference<Map<String, dynamic>> couponReference =
        _couponCollection(normalizedShopId).doc();

    final MemberCouponModel coupon = MemberCouponModel(
      id: couponReference.id,
      shopId: normalizedShopId,
      userId: normalizedUserId,
      name: normalizedName,
      description: description.trim(),
      type: type,
      applyTarget: applyTarget,
      source: MemberCouponSource.pointsExchange,
      status: MemberCouponStatus.available,
      discountValue: discountValue,
      minimumAmount: minimumAmount < 0 ? 0 : minimumAmount,
      maximumDiscountAmount: maximumDiscountAmount < 0
          ? 0
          : maximumDiscountAmount,
      freeStayNights: freeStayNights < 0 ? 0 : freeStayNights,
      serviceId: serviceId.trim(),
      serviceName: serviceName.trim(),
      serviceCategory: serviceCategory,
      roomTypeIds: roomTypeIds
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toSet()
          .toList(),
      startAt: startAt,
      expireAt: expireAt,
      usageLimit: usageLimit,
      usedCount: 0,
      issuedBy: '',
      issuedReason: '',
      pointsCost: pointsCost,
      pointRewardId: normalizedRewardId,
      usedBookingId: '',
      createdAt: now,
      updatedAt: now,
    );

    await couponReference.set(coupon.toMap());

    return couponReference.id;
  }

  /// 預約送出後保留優惠券
  ///
  /// 優惠券保留後暫時不能再次套用其他訂單，
  /// 等訂單完成時才正式核銷。
  Future<void> reserveCoupon({
    required String shopId,
    required String couponId,
    required String userId,
    required String bookingId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedCouponId = couponId.trim();
    final String normalizedUserId = userId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty ||
        normalizedCouponId.isEmpty ||
        normalizedUserId.isEmpty ||
        normalizedBookingId.isEmpty) {
      throw ArgumentError('保留優惠券資料不完整');
    }

    final DocumentReference<Map<String, dynamic>> couponReference =
        _couponCollection(normalizedShopId).doc(normalizedCouponId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(couponReference);

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('找不到此優惠券');
      }

      final MemberCouponModel coupon = MemberCouponModel.fromMap(
        id: snapshot.id,
        data: data,
      );

      if (coupon.userId != normalizedUserId) {
        throw StateError('此優惠券不屬於目前會員');
      }

      if (coupon.status != MemberCouponStatus.available) {
        throw StateError('此優惠券目前不可保留');
      }

      /// 尚未使用的優惠券不應綁定其他訂單。
      ///
      /// 如果 usedBookingId 已經有值，而且不是目前這張訂單，
      /// 代表優惠券可能已被其他訂單占用。
      final String existingBookingId = coupon.usedBookingId.trim();

      if (existingBookingId.isNotEmpty &&
          existingBookingId != normalizedBookingId) {
        throw StateError('此優惠券已被其他訂單使用');
      }

      transaction.update(couponReference, <String, dynamic>{
        'status': MemberCouponStatus.reserved.name,
        'usedBookingId': normalizedBookingId,
        'usedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 核銷優惠券
  ///
  /// 使用 Firestore Transaction，避免同一張券被兩張訂單同時使用。
  Future<void> redeemCoupon({
    required String shopId,
    required String couponId,
    required String userId,
    required String bookingId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedCouponId = couponId.trim();
    final String normalizedUserId = userId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty ||
        normalizedCouponId.isEmpty ||
        normalizedUserId.isEmpty ||
        normalizedBookingId.isEmpty) {
      throw ArgumentError('核銷優惠券資料不完整');
    }

    final DocumentReference<Map<String, dynamic>> couponReference =
        _couponCollection(normalizedShopId).doc(normalizedCouponId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(couponReference);

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('找不到此優惠券');
      }

      final MemberCouponModel coupon = MemberCouponModel.fromMap(
        id: snapshot.id,
        data: data,
      );

      if (coupon.userId != normalizedUserId) {
        throw StateError('此優惠券不屬於目前會員');
      }

      if (coupon.status != MemberCouponStatus.reserved) {
        throw StateError('此優惠券不是保留狀態');
      }

      if (coupon.usedBookingId != normalizedBookingId) {
        throw StateError('此優惠券保留的訂單不一致');
      }

      final int nextUsedCount = coupon.usedCount + 1;

      transaction.update(couponReference, <String, dynamic>{
        'usedCount': nextUsedCount,
        'status': MemberCouponStatus.used.name,
        'usedBookingId': normalizedBookingId,
        'usedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 訂單取消後退回優惠券
  ///
  /// 只有該張券記錄的 usedBookingId 與取消訂單相同時才會退回。
  Future<void> restoreCouponForCancelledBooking({
    required String shopId,
    required String couponId,
    required String bookingId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedCouponId = couponId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty ||
        normalizedCouponId.isEmpty ||
        normalizedBookingId.isEmpty) {
      throw ArgumentError('退回優惠券資料不完整');
    }

    final DocumentReference<Map<String, dynamic>> couponReference =
        _couponCollection(normalizedShopId).doc(normalizedCouponId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(couponReference);

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return;
      }

      final MemberCouponModel coupon = MemberCouponModel.fromMap(
        id: snapshot.id,
        data: data,
      );

      if (coupon.usedBookingId != normalizedBookingId) {
        return;
      }

      final int nextUsedCount = coupon.usedCount > 0 ? coupon.usedCount - 1 : 0;

      final MemberCouponStatus nextStatus = coupon.isRevoked
          ? MemberCouponStatus.revoked
          : MemberCouponStatus.available;

      transaction.update(couponReference, <String, dynamic>{
        'usedCount': nextUsedCount,
        'status': nextStatus.name,
        'usedBookingId': '',
        'usedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 店家撤銷尚未使用的優惠券
  Future<void> revokeCoupon({
    required String shopId,
    required String couponId,
    String reason = '',
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedCouponId = couponId.trim();

    if (normalizedShopId.isEmpty || normalizedCouponId.isEmpty) {
      throw ArgumentError('撤銷優惠券資料不完整');
    }

    final DocumentReference<Map<String, dynamic>> couponReference =
        _couponCollection(normalizedShopId).doc(normalizedCouponId);

    await _firestore.runTransaction((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get(couponReference);

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('找不到此優惠券');
      }

      final MemberCouponModel coupon = MemberCouponModel.fromMap(
        id: snapshot.id,
        data: data,
      );

      if (coupon.isUsed || coupon.usedCount > 0) {
        throw StateError('已使用的優惠券不能撤銷');
      }

      transaction.update(couponReference, <String, dynamic>{
        'status': MemberCouponStatus.revoked.name,
        'revokedBy': _auth.currentUser?.uid ?? '',
        'revokedReason': reason.trim(),
        'revokedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 將過期但仍標記 available 的優惠券更新為 expired
  ///
  /// 後續可由後台頁面進入時呼叫，
  /// 或改由 Cloud Functions 排程統一處理。
  Future<int> markExpiredCoupons({
    required String shopId,
    String? userId,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId?.trim() ?? '';

    if (normalizedShopId.isEmpty) {
      return 0;
    }

    Query<Map<String, dynamic>> query = _couponCollection(
      normalizedShopId,
    ).where('status', isEqualTo: MemberCouponStatus.available.name);

    if (normalizedUserId.isNotEmpty) {
      query = query.where('userId', isEqualTo: normalizedUserId);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    final DateTime now = DateTime.now();
    final WriteBatch batch = _firestore.batch();

    int updateCount = 0;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
        in snapshot.docs) {
      final MemberCouponModel coupon = MemberCouponModel.fromMap(
        id: document.id,
        data: document.data(),
      );

      final DateTime? expireAt = coupon.expireAt;

      if (expireAt == null || !now.isAfter(expireAt)) {
        continue;
      }

      batch.update(document.reference, <String, dynamic>{
        'status': MemberCouponStatus.expired.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      updateCount += 1;
    }

    if (updateCount > 0) {
      await batch.commit();
    }

    return updateCount;
  }

  List<MemberCouponModel> _couponListFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> document,
    ) {
      return MemberCouponModel.fromMap(id: document.id, data: document.data());
    }).toList();
  }

  void _validateCouponContent({
    required MemberCouponType type,
    required num discountValue,
    required int freeStayNights,
    required String serviceId,
    required int usageLimit,
    required DateTime? startAt,
    required DateTime? expireAt,
  }) {
    if (usageLimit <= 0) {
      throw ArgumentError('優惠券使用次數必須大於 0');
    }

    if (startAt != null && expireAt != null && expireAt.isBefore(startAt)) {
      throw ArgumentError('優惠券到期日不能早於開始日');
    }

    switch (type) {
      case MemberCouponType.fixedAmount:
        if (discountValue <= 0) {
          throw ArgumentError('固定金額折價券的折抵金額必須大於 0');
        }
        break;

      case MemberCouponType.percent:
        if (discountValue <= 0 || discountValue >= 100) {
          throw ArgumentError('百分比折價券必須設定 1 至 99 的折扣百分比');
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
