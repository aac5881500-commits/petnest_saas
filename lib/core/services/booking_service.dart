// 檔案名稱：lib/core/services/booking_service.dart
// 功能說明：預約服務層（區間預約版）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/terms_consent_snapshot.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/inventory_stock_service.dart';
import 'package:petnest_saas/core/services/booking_inventory_function_service.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:flutter/foundation.dart';

class BookingService {
  BookingService._();
  static final instance = BookingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get _currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  /// ===============================
  /// 🧾 產生店家訂單編號
  /// 格式：SHOP0001-B000001
  /// ===============================
  Future<String> _generateBookingCode(String shopId) async {
    final counterRef = _firestore.collection('booking_counters').doc(shopId);

    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);

      final current = snapshot.exists
          ? (snapshot.data()?['current'] ?? 0) as int
          : 0;

      final next = current + 1;

      transaction.set(counterRef, {
        'current': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return '$shopId-B${next.toString().padLeft(6, '0')}';
    });
  }

  /// 建立預約（區間版）
  Future<String> createBooking({
    required String shopId,
    required String customerName,
    required String customerPhone,
    required List<String> petIds,
    required String serviceType,
    required DateTime startDate,
    required DateTime endDate,
    required int nights,
    required String roomId,
    required String roomName,
    required String roomTypeName,
    required int basePrice,
    required int extraPetPrice,
    required int extraPetCount,
    required int extraPetTotal,
    required int roomSubtotal,
    required List<dynamic> roomImages,
    String note = '',
    String address = '',
    String emergencyName = '',
    String emergencyPhone = '',
    String emergencyRelation = '',
    String emergencyAddress = '',
    String emergencyPhone2 = '',
    int totalPrice = 0,

    int originalTotal = 0,
    int specialDateSurchargeAmount = 0,
    List<Map<String, dynamic>> specialDateSurchargeDetails =
        const <Map<String, dynamic>>[],
    int discountAmount = 0,
    int discountUsedNights = 0,
    int discountPercent = 0,
    int discountMinNights = 0,
    String discountBase = '',

    String discountCampaignId = '',
    String discountCampaignName = '',
    String discountCampaignDescription = '',
    String discountCampaignType = '',
    String discountValueType = '',
    num discountValue = 0,
    bool allowCouponTogether = false,

    String couponId = '',
    String couponName = '',
    String couponType = '',
    int couponDiscountAmount = 0,

    int depositAmount = 0,
    String paymentMethod = '',
    String payAmountType = '', // deposit / full
    List<Map<String, dynamic>>? pets,
    List<Map<String, dynamic>>? addons,
    int policyVersion = 0,
    String policyTitle = '入住須知',
    Timestamp? policyAcceptedAt,
    TermsConsentSnapshot? termsConsent,

    /// 🔒 同一次送出請求的唯一識別碼，用來避免網路重送建立兩筆訂單
    String requestId = '',
  }) async {
    final user = _currentUser;

    /// 🔒 有 requestId 時固定使用同一個訂單文件 ID
    final normalizedRequestId = requestId.trim();

    final doc = normalizedRequestId.isNotEmpty
        ? _bookings.doc(normalizedRequestId)
        : _bookings.doc();

    /// 🔒 相同請求已經建立過，就直接回傳原訂單，不再重建。
    /// 若上次停在「訂單已寫入、加購庫存尚未扣除」，這裡會再走一次
    /// 幂等 finalize，避免留下沒扣庫存的有效訂單。
    if (normalizedRequestId.isNotEmpty) {
      final existingBooking = await doc.get();

      if (existingBooking.exists) {
        final String existingStatus = (existingBooking.data()?['status'] ?? '')
            .toString();
        if (existingStatus == 'cancelled' ||
            existingBooking.data()?['cancelledAt'] != null) {
          debugPrint(
            '[BookingSubmit] existing requestId booking is cancelled: ${doc.id}',
          );
          throw const InventoryException('此預約無法完成，請重新送出');
        }
        debugPrint(
          '[BookingSubmit] existing requestId booking found: ${doc.id}',
        );
        await _afterBookingCreated(shopId: shopId, bookingId: doc.id);
        return doc.id;
      }
    }
    debugPrint('FRONT_BOOKING_STEP: generate code start');
    final bookingCode = await _generateBookingCode(shopId);
    debugPrint('FRONT_BOOKING_STEP: generate code ok');
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);

    /// 🔥 取得店家付款資料快照
    final shopDoc = await _firestore.collection('shops').doc(shopId).get();

    final shopData = shopDoc.data() ?? {};

    final bankName = shopData['bankName'] ?? '';
    final accountName = shopData['accountName'] ?? '';
    final accountNumber = shopData['accountNumber'] ?? '';
    final depositExpireHours = shopData['depositExpireHours'] ?? 1;

    // 🔥 取得寵物資料（快照）
    if (user == null) throw Exception('未登入');

    final petDocs = await _firestore
        .collection('user_profiles')
        .doc(user.uid)
        .collection('pets')
        .where(FieldPath.documentId, whereIn: petIds)
        .get();

    final finalPets = petDocs.docs.map((doc) {
      final p = doc.data();

      return {
        'name': p['name'],
        'breed': p['breed'],
        'gender': p['gender'],
        'age': p['age'],
        'isNeutered': p['isNeutered'],

        /// 🔥 修正這裡
        'photoUrl': p['photoUrl'] ?? '',

        'medicalStatus': p['vaccine'],
        'litterType': p['litterType'],

        'note': p['note'],
        'staffNote': p['adminNote'] ?? '',
      };
    }).toList();

    final bookingId = await _firestore.runTransaction<String>((
      transaction,
    ) async {
      /// 🔒 Transaction 內重新讀取，防止兩個請求同時建立
      final existingBooking = await transaction.get(doc);

      if (existingBooking.exists) {
        debugPrint('BOOKING_IDEMPOTENCY: 已存在，直接回傳 ${doc.id}');
        return doc.id;
      }

      transaction.set(doc, {
        'requestId': normalizedRequestId,
        'addons': (addons ?? []).isNotEmpty ? addons : [],
        'bookingId': doc.id,
        'bookingCode': bookingCode,
        'shopId': shopId,
        'shopName': shopData['name'],
        'userId': user.uid,
        'policyVersion': policyVersion,
        'policyTitle': policyTitle,
        'policyAcceptedAt': policyAcceptedAt ?? FieldValue.serverTimestamp(),
        if (termsConsent != null) ...termsConsent.toBookingFields(),
        'customerName': customerName.trim(),
        'customerPhone': customerPhone.trim(),
        'address': address,
        'roomTypeName': roomTypeName,
        'basePrice': basePrice,
        'extraPetPrice': extraPetPrice,
        'extraPetCount': extraPetCount,
        'extraPetTotal': extraPetTotal,
        'roomSubtotal': roomSubtotal,
        'roomImages': roomImages,
        'emergencyContact': {
          'name': emergencyName,
          'phone': emergencyPhone,
          'relation': emergencyRelation,
          'address': emergencyAddress,
          'phone2': emergencyPhone2,
        },
        'petIds': petIds,
        'pets': finalPets,
        'roomTypeId': roomId,
        'roomId': null,
        'roomName': null,
        'assignStatus': 'unassigned',
        'serviceType': serviceType,
        'bookingKind': 'accommodation',

        /// 區間日期
        'startDate': Timestamp.fromDate(normalizedStart),
        'endDate': Timestamp.fromDate(normalizedEnd),
        'nights': nights,

        /// 狀態
        'status': 'pending', // pending / confirmed / completed / cancelled
        /// 備註
        'note': note.trim(),

        /// 價格欄位
        'totalPrice': totalPrice,

        'originalTotal': originalTotal,

        /// 📅 特殊日期加價快照
        ///
        /// 與特殊日期加價設定文件分離保存，
        /// 避免店家日後修改或刪除設定影響歷史訂單。
        'specialDateSurchargeAmount': specialDateSurchargeAmount,
        'specialDateSurchargeDetails': specialDateSurchargeDetails,

        'discountAmount': discountAmount,
        'discountUsedNights': discountUsedNights,
        'discountPercent': discountPercent,
        'discountMinNights': discountMinNights,
        'discountBase': discountBase,

        'discountCampaignId': discountCampaignId,
        'discountCampaignName': discountCampaignName,
        'discountCampaignDescription': discountCampaignDescription.trim(),
        'discountCampaignType': discountCampaignType,
        'discountValueType': discountValueType,
        'discountValue': discountValue,
        'allowCouponTogether': allowCouponTogether,

        'couponId': couponId,
        'couponName': couponName,
        'couponType': couponType,
        'couponDiscountAmount': couponDiscountAmount,

        'depositAmount': depositAmount,
        'paymentMethod': paymentMethod,
        'payAmountType': payAmountType,

        /// 💰 Booking 付款摘要初始值
        ///
        /// Booking 與 Payment 採分離架構：
        /// - Booking 建立後永久保留
        /// - 每次付款另外建立 payments 紀錄
        /// - 付款成功後再由 Cloud Functions 更新以下摘要
        'paidAmount': 0,
        'remainingAmount': totalPrice,
        'paymentStatus': 'unpaid',
        'lastPaymentId': null,
        'lastMerchantTradeNo': null,
        'paymentUpdatedAt': null,
        'paidAt': null,

        /// 🔥 店家轉帳資訊快照
        'bankName': bankName,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'depositExpireHours': depositExpireHours,
        'depositExpireAt':
            paymentMethod == 'transfer' || paymentMethod == 'cash'
            ? Timestamp.fromDate(
                DateTime.now().add(
                  depositExpireHours == 0
                      ? const Duration(minutes: 1)
                      : Duration(hours: depositExpireHours),
                ),
              )
            : null,

        /// 未來預留
        'checkedInAt': null,
        'checkedOutAt': null,
        'cameraAccessEnabled': false,
        'cameraUrl': null,

        /// 系統欄位
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('BOOKING_IDEMPOTENCY: 建立成功 ${doc.id}');
      return doc.id;
    });

    debugPrint(
      '[BookingSubmit] create booking success: $bookingId shopId=$shopId',
    );
    await _afterBookingCreated(shopId: shopId, bookingId: bookingId);
    return bookingId;
  }

  Future<String> createAdminBooking({
    required String shopId,
    required String userId,
    required String customerName,
    required String customerPhone,
    required List<String> petIds,
    required String serviceType,
    required DateTime startDate,
    required DateTime endDate,
    required int nights,
    required String roomId,
    required String roomName,
    required String roomTypeName,
    required int basePrice,
    required int extraPetPrice,
    required int extraPetCount,
    required int extraPetTotal,
    required int roomSubtotal,
    required List<dynamic> roomImages,
    String note = '',
    String address = '',
    String emergencyName = '',
    String emergencyPhone = '',
    String emergencyRelation = '',
    String emergencyAddress = '',
    String emergencyPhone2 = '',
    int totalPrice = 0,
    int originalTotal = 0,

    int specialDateSurchargeAmount = 0,
    List<Map<String, dynamic>> specialDateSurchargeDetails =
        const <Map<String, dynamic>>[],

    bool applyLongStayDiscount = false,
    int discountAmount = 0,
    int discountPercent = 0,
    int discountMinNights = 0,
    int discountUsedNights = 0,
    String discountBase = '',
    String discountCampaignId = '',
    String discountCampaignName = '',
    String discountCampaignDescription = '',
    String discountCampaignType = '',
    String discountValueType = '',
    num discountValue = 0,
    bool allowCouponTogether = false,
    int depositAmount = 0,
    String paymentMethod = '',
    String payAmountType = '', // deposit / full
    List<Map<String, dynamic>>? pets,
    List<Map<String, dynamic>>? addons,
  }) async {
    final operator = _currentUser;
    final doc = _bookings.doc();

    debugPrint('ADMIN_BOOKING_STEP 1: 開始產生訂單編號');

    final bookingCode = await _generateBookingCode(shopId);

    debugPrint('ADMIN_BOOKING_STEP 2: 訂單編號=$bookingCode');
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);

    /// 🔥 取得店家付款資料快照
    final shopDoc = await _firestore.collection('shops').doc(shopId).get();

    final shopData = shopDoc.data() ?? {};

    final bankName = shopData['bankName'] ?? '';
    final accountName = shopData['accountName'] ?? '';
    final accountNumber = shopData['accountNumber'] ?? '';
    final depositExpireHours = shopData['depositExpireHours'] ?? 1;

    // 🔥 取得寵物資料（快照）
    if (operator == null) throw Exception('未登入');

    final finalPets = (pets ?? []).map((p) {
      return {
        'petId': p['petId'] ?? '',
        'name': p['name'] ?? '',
        'type': p['type'] ?? '',
        'breed': p['breed'] ?? '',
        'gender': p['gender'] ?? '',
        'age': p['age'] ?? '',
        'isNeutered': p['isNeutered'] ?? false,
        'photoUrl': p['photoUrl'] ?? p['imageUrl'] ?? '',
        'vaccine': p['vaccine'] ?? '',
        'medicalStatus': p['medicalStatus'] ?? p['vaccine'] ?? '',
        'litterType': p['litterType'] ?? '',
        'note': p['note'] ?? '',
        'staffNote': p['staffNote'] ?? p['adminNote'] ?? '',
      };
    }).toList();

    debugPrint('ADMIN_BOOKING_STEP 3: 開始寫入 booking');

    await doc.set({
      'addons': (addons ?? []).isNotEmpty ? addons : [],
      'bookingId': doc.id,
      'bookingCode': bookingCode,
      'shopId': shopId,
      'shopName': shopData['name'],
      'userId': userId,
      'source': 'admin',
      'createdByUid': operator.uid,
      'createdByEmail': operator.email,
      'customerName': customerName.trim(),
      'customerPhone': customerPhone.trim(),
      'address': address,
      'roomTypeName': roomTypeName,
      'basePrice': basePrice,
      'extraPetPrice': extraPetPrice,
      'extraPetCount': extraPetCount,
      'extraPetTotal': extraPetTotal,
      'roomSubtotal': roomSubtotal,
      'roomImages': roomImages,
      'emergencyContact': {
        'name': emergencyName,
        'phone': emergencyPhone,
        'relation': emergencyRelation,
        'address': emergencyAddress,
        'phone2': emergencyPhone2,
      },
      'petIds': petIds,
      'pets': finalPets,
      'roomTypeId': roomId,
      'roomId': null,
      'roomName': null,
      'assignStatus': 'unassigned',
      'serviceType': serviceType,
      'bookingKind': 'accommodation',

      /// 區間日期
      'startDate': Timestamp.fromDate(normalizedStart),
      'endDate': Timestamp.fromDate(normalizedEnd),
      'nights': nights,

      /// 狀態
      'status': 'pending', // pending / confirmed / completed / cancelled
      /// 備註
      'note': note.trim(),

      /// 價格欄位
      'totalPrice': totalPrice,
      'originalTotal': originalTotal,

      /// 📅 特殊日期加價快照
      'specialDateSurchargeAmount': specialDateSurchargeAmount,
      'specialDateSurchargeDetails': specialDateSurchargeDetails,

      'applyLongStayDiscount': applyLongStayDiscount,
      'discountAmount': discountAmount,
      'discountUsedNights': discountUsedNights,
      'discountPercent': discountPercent,
      'discountMinNights': discountMinNights,
      'discountBase': discountBase,
      'discountCampaignId': discountCampaignId,
      'discountCampaignName': discountCampaignName,
      'discountCampaignDescription': discountCampaignDescription.trim(),
      'discountCampaignType': discountCampaignType,
      'discountValueType': discountValueType,
      'discountValue': discountValue,
      'allowCouponTogether': allowCouponTogether,
      'depositAmount': depositAmount,
      'paymentMethod': paymentMethod,
      'payAmountType': payAmountType,

      /// 💰 Booking 付款摘要初始值
      ///
      /// 後台手動建立的訂單也使用相同付款摘要格式，
      /// 避免會員訂單與手動訂單的資料結構不同。
      'paidAmount': 0,
      'remainingAmount': totalPrice,
      'paymentStatus': 'unpaid',
      'lastPaymentId': null,
      'lastMerchantTradeNo': null,
      'paymentUpdatedAt': null,
      'paidAt': null,

      /// 🔥 店家轉帳資訊快照
      'bankName': bankName,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'depositExpireHours': depositExpireHours,
      'depositExpireAt': paymentMethod == 'transfer' || paymentMethod == 'cash'
          ? Timestamp.fromDate(
              DateTime.now().add(
                depositExpireHours == 0
                    ? const Duration(minutes: 1)
                    : Duration(hours: depositExpireHours),
              ),
            )
          : null,

      /// 未來預留
      'checkedInAt': null,
      'checkedOutAt': null,
      'cameraAccessEnabled': false,
      'cameraUrl': null,

      /// 系統欄位
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('ADMIN_BOOKING_STEP 4: booking 寫入完成');

    await _afterBookingCreated(shopId: shopId, bookingId: doc.id);
    return doc.id;
  }

  /// 取得單筆預約
  Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    final doc = await _bookings.doc(bookingId).get();

    if (!doc.exists) return null;

    return {'bookingId': doc.id, ...doc.data()!};
  }

  /// 監聽單筆預約
  Stream<Map<String, dynamic>?> streamBooking(String bookingId) {
    return _bookings.doc(bookingId).snapshots().map((doc) {
      if (!doc.exists) return null;

      return {'bookingId': doc.id, ...doc.data()!};
    });
  }

  /// 監聽某店家的全部預約（最新建立排前面）
  Stream<List<Map<String, dynamic>>> streamShopBookings(String shopId) {
    return _bookings
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'bookingId': doc.id, ...doc.data()};
          }).toList();
        });
  }

  /// 依狀態監聽某店家預約
  Stream<List<Map<String, dynamic>>> streamShopBookingsByStatus({
    required String shopId,
    required String status,
  }) {
    return _bookings
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return {'bookingId': doc.id, ...doc.data()};
          }).toList();
        });
  }

  /// 取得某店家全部預約（一次性）
  Future<List<Map<String, dynamic>>> getShopBookings(String shopId) async {
    final snapshot = await _bookings
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return {'bookingId': doc.id, ...doc.data()};
    }).toList();
  }

  /// ===============================
  /// ❌ 統一取消訂單
  /// ===============================
  /// 功能：
  /// - 更新 bookings 狀態為 cancelled
  /// - 寫入取消原因 / 取消來源
  /// - 釋放 room_calendar 房間
  Future<void> cancelBooking({
    required String bookingId,
    required String cancelReason,
    required String cancelBy, // customer / admin / system
  }) async {
    final docRef = _bookings.doc(bookingId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('訂單不存在');
    }

    final data = doc.data();
    if (data == null) {
      throw Exception('訂單資料不存在');
    }

    final status = data['status']?.toString() ?? '';
    final cancelledAt = data['cancelledAt'];

    /// 已取消就不重複處理
    if (status == 'cancelled' || cancelledAt != null) return;

    await docRef.update({
      'status': 'cancelled',
      'assignStatus': data['assignStatus'] ?? 'unassigned',
      'cancelReason': cancelReason,
      'cancelBy': cancelBy,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final String couponShopId = (data['shopId'] ?? '').toString().trim();
    final String couponId = (data['couponId'] ?? '').toString().trim();

    if (couponShopId.isNotEmpty && couponId.isNotEmpty) {
      try {
        await MemberCouponService.instance.restoreCouponForCancelledBooking(
          shopId: couponShopId,
          couponId: couponId,
          bookingId: bookingId,
        );
      } catch (error, stackTrace) {
        debugPrint('取消訂單退回優惠券失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final shopId = data['shopId'];
    final roomId = data['roomId'];
    final startDate = data['startDate'];
    final endDate = data['endDate'];

    if (shopId != null &&
        roomId != null &&
        roomId.toString().isNotEmpty &&
        startDate is Timestamp &&
        endDate is Timestamp) {
      await releaseRoomCalendar(
        shopId: shopId,
        roomId: roomId,
        startDate: startDate.toDate(),
        endDate: endDate.toDate(),
      );
    }

    await _returnBookingInventory(
      shopId: (data['shopId'] ?? '').toString(),
      bookingId: bookingId,
    );

    await _firestore.collection('action_logs').add({
      'type': 'booking_cancelled',

      /// 訂單資訊
      'bookingId': bookingId,
      'bookingShortId': bookingId.substring(0, 8),
      'shopId': data['shopId'],
      'roomId': data['roomId'],
      'roomName': data['roomName'],
      'roomTypeName': data['roomTypeName'],

      /// 狀態變化
      'fromStatus': status,
      'toStatus': 'cancelled',

      /// 取消資訊
      'cancelReason': cancelReason,
      'cancelBy': cancelBy, // customer / admin / system
      /// 操作者
      'operatorUid': _currentUser?.uid,
      'operatorRole': cancelBy,
      'operatorEmail': _currentUser?.email,

      /// 時間
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ===============================
  /// 🔁 更換房間（預留入住中換房用）
  /// ===============================
  /// 功能：
  /// - 釋放舊房間 room_calendar
  /// - 檢查新房間是否可用
  /// - 鎖定新房間
  /// - 更新 booking 房號
  Future<void> changeAssignedRoom({
    required String bookingId,
    required String shopId,
    required String oldRoomId,
    required String oldRoomName,
    required String newRoomId,
    required String newRoomName,
    required DateTime startDate,
    required DateTime endDate,
    String reason = '',
  }) async {
    final available = await isRoomAvailable(
      shopId: shopId,
      roomId: newRoomId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!available) {
      throw Exception('新房間在該日期區間已被預約');
    }

    await releaseRoomCalendar(
      shopId: shopId,
      roomId: oldRoomId,
      startDate: startDate,
      endDate: endDate,
    );

    await blockRoomCalendar(
      shopId: shopId,
      roomId: newRoomId,
      startDate: startDate,
      endDate: endDate,
    );

    await _bookings.doc(bookingId).update({
      'roomId': newRoomId,
      'roomName': newRoomName,
      'assignStatus': 'assigned',
      'roomChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('action_logs').add({
      'type': 'room_changed',
      'bookingId': bookingId,
      'bookingShortId': bookingId.substring(0, 8),
      'shopId': shopId,
      'oldRoomId': oldRoomId,
      'oldRoomName': oldRoomName,
      'newRoomId': newRoomId,
      'newRoomName': newRoomName,
      'reason': reason,
      'operatorUid': _currentUser?.uid,
      'operatorEmail': _currentUser?.email,
      'operatorRole': 'staff',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 更新預約狀態
  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await _bookings.doc(bookingId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 確認入住
  ///
  /// 住宿耗材在入住當下依最新晚數與寵物數扣除（僅店家成員）。
  /// 加購庫存已在建立訂單時由 Functions 扣除；
  /// 這裡再嘗試一次，看到 ba_{bookingId}_deduct 即安全 skip。
  Future<void> checkInBooking({required String bookingId}) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _bookings
        .doc(bookingId)
        .get();

    final Map<String, dynamic>? data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw Exception('找不到這筆訂單');
    }

    final String shopId = (data['shopId'] ?? '').toString();
    final String status = (data['status'] ?? '').toString();

    if (status == 'cancelled') {
      throw Exception('訂單已取消，無法入住');
    }

    if (shopId.isEmpty) {
      await _bookings.doc(bookingId).update({
        'status': 'checked_in',
        'checkInAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await BookingInventoryFunctionService.instance
        .finalizeBookingAddonInventory(shopId: shopId, bookingId: bookingId);
    await InventoryStockService.instance.consumeBookingSupplies(
      shopId: shopId,
      bookingId: bookingId,
    );

    await _bookings.doc(bookingId).update({
      'status': 'checked_in',
      'checkInAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _afterBookingCreated({
    required String shopId,
    required String bookingId,
  }) async {
    try {
      debugPrint(
        '[BookingSubmit] finalize inventory start bookingId=$bookingId shopId=$shopId',
      );
      await BookingInventoryFunctionService.instance
          .finalizeBookingAddonInventory(shopId: shopId, bookingId: bookingId);
      debugPrint(
        '[BookingSubmit] finalize inventory done bookingId=$bookingId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[BookingSubmit] finalize failed: $error bookingId=$bookingId',
      );
      debugPrintStack(stackTrace: stackTrace);

      try {
        await cancelBooking(
          bookingId: bookingId,
          cancelReason: InventoryException.userMessage(error),
          cancelBy: 'system',
        );
        debugPrint('[BookingSubmit] rollback cancelled bookingId=$bookingId');
      } catch (rollbackError, rollbackStack) {
        debugPrint(
          '[BookingSubmit] rollback failed: $rollbackError bookingId=$bookingId',
        );
        debugPrintStack(stackTrace: rollbackStack);
      }

      if (error is InventoryException) {
        rethrow;
      }

      throw InventoryException(InventoryException.userMessage(error));
    }

    final DocumentSnapshot<Map<String, dynamic>> latest = await _bookings
        .doc(bookingId)
        .get();
    final Map<String, dynamic>? latestData = latest.data();
    if ((latestData?['status'] ?? '').toString() == 'cancelled') {
      final String reason = (latestData?['cancelReason'] ?? '此預約無法完成，請重新送出')
          .toString()
          .trim();
      throw InventoryException(reason.isEmpty ? '此預約無法完成，請重新送出' : reason);
    }
  }

  Future<void> _returnBookingInventory({
    required String shopId,
    required String bookingId,
  }) async {
    if (shopId.trim().isEmpty || bookingId.trim().isEmpty) {
      return;
    }

    try {
      await BookingInventoryFunctionService.instance.returnBookingInventory(
        shopId: shopId,
        bookingId: bookingId,
      );
    } catch (error, stackTrace) {
      debugPrint('取消訂單返還庫存失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// ===============================
  /// 🏠 後台分配房間
  /// ===============================
  /// 功能：
  /// - 確認房間區間可用
  /// - 更新 booking 房號
  /// - assignStatus 改為 assigned
  /// - 寫入 room_calendar 鎖房
  Future<void> assignRoomToBooking({
    required String bookingId,
    required String shopId,
    required String roomId,
    required String roomName,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final bookingDoc = await _bookings.doc(bookingId).get();

    if (!bookingDoc.exists) {
      throw Exception('找不到這筆訂單');
    }

    final bookingData = bookingDoc.data() ?? <String, dynamic>{};
    final bookingStatus = bookingData['status']?.toString() ?? '';

    if (bookingStatus != 'confirmed') {
      throw Exception('此訂單尚未確認，不能進行分房');
    }
    final available = await isRoomAvailable(
      shopId: shopId,
      roomId: roomId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!available) {
      throw Exception('此房間在該日期區間已被預約');
    }

    await _bookings.doc(bookingId).update({
      'roomId': roomId,
      'roomName': roomName,
      'assignStatus': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await blockRoomCalendar(
      shopId: shopId,
      roomId: roomId,
      startDate: startDate,
      endDate: endDate,
    );

    await _firestore.collection('action_logs').add({
      'type': 'room_assigned',
      'bookingId': bookingId,
      'bookingShortId': bookingId.substring(0, 8),
      'shopId': shopId,
      'roomId': roomId,
      'roomName': roomName,
      'operatorUid': _currentUser?.uid,
      'operatorEmail': _currentUser?.email,
      'operatorRole': 'staff',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 更新預約資料
  Future<void> updateBooking({
    required String bookingId,
    String? customerName,
    String? customerPhone,
    String? petName,
    String? petType,
    String? serviceType,
    DateTime? startDate,
    DateTime? endDate,
    int? nights,
    String? note,
    int? totalPrice,
    int? pricePerNight,
    String? roomId,
    String? roomName,
    bool? cameraAccessEnabled,
    String? cameraUrl,
  }) async {
    final Map<String, dynamic> data = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (customerName != null) data['customerName'] = customerName.trim();
    if (customerPhone != null) data['customerPhone'] = customerPhone.trim();
    if (petName != null) data['petName'] = petName.trim();
    if (petType != null) data['petType'] = petType.trim();
    if (serviceType != null) data['serviceType'] = serviceType;
    if (startDate != null) {
      data['startDate'] = Timestamp.fromDate(_dateOnly(startDate));
    }
    if (endDate != null) {
      data['endDate'] = Timestamp.fromDate(_dateOnly(endDate));
    }
    if (nights != null) data['nights'] = nights;
    if (note != null) data['note'] = note.trim();
    if (totalPrice != null) data['totalPrice'] = totalPrice;
    if (pricePerNight != null) data['pricePerNight'] = pricePerNight;
    if (roomId != null) data['roomId'] = roomId;
    if (roomName != null) data['roomName'] = roomName;
    if (cameraAccessEnabled != null) {
      data['cameraAccessEnabled'] = cameraAccessEnabled;
    }
    if (cameraUrl != null) data['cameraUrl'] = cameraUrl;

    await _bookings.doc(bookingId).update(data);
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return _dateOnly(value.toDate());
    if (value is DateTime) return _dateOnly(value);
    return null;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// ===============================
  /// 🔒 檢查房間在區間是否可用
  /// ===============================
  Future<bool> isRoomAvailable({
    required String shopId,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    // ======================
    // 先檢查 room_calendar
    // ======================

    final stayDates = getStayDates(startDate: start, endDate: end);

    for (final date in stayDates) {
      final dateKey = ShopService.instance.formatDateKey(date);

      final calendarDoc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('room_calendar')
          .doc('${roomId}_$dateKey')
          .get();

      if (calendarDoc.exists) {
        final status = calendarDoc.data()?['status']?.toString() ?? '';

        if (status == 'blocked' ||
            status == 'maintenance' ||
            status == 'closed' ||
            status == 'cleaning' ||
            status == 'unavailable' ||
            status == 'booked' ||
            status == 'checked_in' ||
            status == 'occupied') {
          return false;
        }
      }
    }

    // ======================
    // 再檢查 bookings
    // ======================

    final bookings = await getShopBookings(shopId);

    for (final booking in bookings) {
      final status = booking['status']?.toString() ?? '';

      if (status == 'cancelled' || status == 'completed') continue;

      if (booking['roomId'] != roomId) continue;
      final bStart = _timestampToDate(booking['startDate']);
      final bEnd = _timestampToDate(booking['endDate']);

      if (bStart == null || bEnd == null) continue;

      final overlap = start.isBefore(bEnd) && end.isAfter(bStart);

      if (overlap) {
        return false;
      }
    }

    return true;
  }

  /// ===============================
  /// 🔒 將房間寫入日曆（鎖房）
  /// ===============================
  Future<void> blockRoomCalendar({
    required String shopId,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final stayDates = getStayDates(startDate: startDate, endDate: endDate);

    final batch = _firestore.batch();

    for (final date in stayDates) {
      final dateKey = ShopService.instance.formatDateKey(date);

      final docRef = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('room_calendar')
          .doc('${roomId}_$dateKey');

      batch.set(docRef, {
        'roomId': roomId,
        'date': dateKey,
        'status': 'booked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// ===============================
  /// 🔓 釋放房間（取消訂單）
  /// ===============================
  Future<void> releaseRoomCalendar({
    required String shopId,
    required String roomId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final stayDates = getStayDates(startDate: startDate, endDate: endDate);

    final batch = _firestore.batch();

    for (final date in stayDates) {
      final dateKey = ShopService.instance.formatDateKey(date);

      final docRef = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('room_calendar')
          .doc('${roomId}_$dateKey');

      batch.delete(docRef); // 🔥 直接刪掉
    }

    await batch.commit();
  }

  /// ===============================
  /// 📅 取得入住日期區間
  /// ===============================
  List<DateTime> getStayDates({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);

    final List<DateTime> result = [];

    DateTime cursor = start;
    while (cursor.isBefore(end)) {
      result.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    return result;
  }

  /// ===============================
  /// 🌙 計算晚數
  /// ===============================
  int calculateNights({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    return end.difference(start).inDays;
  }

  /// ===============================
  /// 💰 計算總價
  /// ===============================
  int calculateTotalPrice({
    required Map<String, dynamic> roomType,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final stayDates = getStayDates(startDate: startDate, endDate: endDate);

    final pricePerNight = _toInt(roomType['price']);

    return stayDates.length * pricePerNight;
  }

  /// ===============================
  /// 🔍 找可用房間（自動分配）
  /// ===============================
  Future<Map<String, dynamic>?> findAvailableRoom({
    required String shopId,
    required String roomTypeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final roomsSnapshot = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('rooms')
        .where('roomTypeId', isEqualTo: roomTypeId)
        .where('enabled', isEqualTo: true)
        .get();

    for (final roomDoc in roomsSnapshot.docs) {
      final roomId = roomDoc.id;

      // 🔥 檢查房間是否被手動關閉
      bool blocked = false;

      final stayDates = getStayDates(startDate: startDate, endDate: endDate);

      for (final date in stayDates) {
        final dateKey = ShopService.instance.formatDateKey(date);

        final calendarDoc = await _firestore
            .collection('shops')
            .doc(shopId)
            .collection('room_calendar')
            .doc('${roomId}_$dateKey')
            .get();

        if (calendarDoc.exists) {
          final data = calendarDoc.data();

          final String calendarStatus = data?['status']?.toString() ?? '';

          if (calendarStatus == 'blocked' ||
              calendarStatus == 'maintenance' ||
              calendarStatus == 'closed' ||
              calendarStatus == 'cleaning' ||
              calendarStatus == 'unavailable' ||
              calendarStatus == 'booked' ||
              calendarStatus == 'checked_in' ||
              calendarStatus == 'occupied') {
            blocked = true;
            break;
          }
        }
      }

      if (blocked) {
        continue;
      }

      final available = await isRoomAvailable(
        shopId: shopId,
        roomId: roomId,
        startDate: startDate,
        endDate: endDate,
      );

      if (available) {
        return {'id': roomId, ...roomDoc.data()};
      }
    }

    return null;
  }

  /// 🔥 計算某一天被佔用幾間房
  Future<int> countRoomsByDate({
    required String shopId,
    required String date,
  }) async {
    final snapshot = await _firestore
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final start = (data['startDate'] as Timestamp).toDate();
      final end = (data['endDate'] as Timestamp).toDate();

      DateTime cursor = DateTime(start.year, start.month, start.day);

      while (!cursor.isAfter(end.subtract(const Duration(days: 1)))) {
        final key = _formatDateKey(cursor);

        if (key == date) {
          count++;
          break;
        }

        cursor = cursor.add(const Duration(days: 1));
      }
    }

    return count;
  }

  /// 日期轉 key（yyyy-MM-dd）
  String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
